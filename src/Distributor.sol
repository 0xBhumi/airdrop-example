// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeCast} from "openzeppelin-contracts/utils/math/SafeCast.sol";
import {IL2ToL2CrossDomainMessenger} from "@contracts-bedrock/interfaces/L2/IL2ToL2CrossDomainMessenger.sol";
import {Predeploys} from "@contracts-bedrock/src/libraries/Predeploys.sol";
import {SuperchainERC20} from "@contracts-bedrock/src/L2/SuperchainERC20.sol";
import {SuperchainTokenBridge} from "@contracts-bedrock/src/L2/SuperchainTokenBridge.sol";

struct MerkleTree {
    bytes32 merkleRoot;
    bytes32 ipfsHash;
}

struct Claim {
    uint208 amount;
    uint48 timestamp;
    bytes32 merkleRoot;
}

struct TransferMessage {
    address recipient;
    uint256 amount;
    address tokenAddress;
}

/// @title Distributor
/// @notice Allows to claim rewards distributed to them
contract Distributor {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                       VARIABLES
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////*/

    // Immutable reference to the L2 CrossDomainMessenger
    IL2ToL2CrossDomainMessenger internal immutable messenger;

    /// @notice Tree of claimable tokens through this contract
    MerkleTree public tree;

    /// @notice Owner of the contract
    address public owner;

    /// @notice Mapping user -> token -> amount to track claimed amounts
    mapping(address => mapping(address => Claim)) public claimed;

    /// @notice Reentrancy status
    uint96 private _status;

    /*//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                        EVENTS
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////*/

    event Claimed(address indexed user, address indexed token, uint256 amount);
    event Recovered(address indexed token, address indexed to, uint256 amount);
    event TreeUpdated(bytes32 merkleRoot, bytes32 ipfsHash);
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /*//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                       ERRORS
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////*/

    error NotTrusted();
    error ReentrantCall();
    error InvalidLengths();
    error NotWhitelisted();
    error InvalidProof();
    error InvalidReturnMessage();
    error InvalidOwner();
    error InvalidUninitializedRoot();
    error CallerNotL2ToL2CrossDomainMessenger();
    error InvalidCrossDomainSender();

    /*//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                       MODIFIERS
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////*/

    /// @notice Checks whether the `msg.sender` is the owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    /// @notice Checks whether the `msg.sender` is the `user` address
    modifier onlyUser(address user) {
        require(user == msg.sender, "Not user");
        _;
    }

    /// @notice Checks whether a call is reentrant or not
    modifier nonReentrant() {
        if (_status == 2) revert ReentrantCall();

        // Any calls to nonReentrant after this point will fail
        _status = 2;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = 1;
    }

    modifier onlyCrossDomainCallback() {
        if (msg.sender != address(messenger))
            revert CallerNotL2ToL2CrossDomainMessenger();
        if (messenger.crossDomainMessageSender() != address(this))
            revert InvalidCrossDomainSender();
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                      CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////*/

    constructor(address _owner) {
        messenger = IL2ToL2CrossDomainMessenger(
            Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER
        );
        owner = _owner;
        emit OwnershipTransferred(address(0), owner);
    }

    /*//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                    MAIN FUNCTIONS
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////*/

    /// @notice Claims rewards for a given set of users
    /// @dev Unless another address has been approved for claiming, only an address can claim for itself
    /// @param users Addresses for which claiming is taking place
    /// @param tokens ERC20 token claimed
    /// @param amounts Amount of tokens that will be sent to the corresponding users
    /// @param proofs Array of hashes bridging from a leaf `(hash of user | token | amount)` to the Merkle root
    function claim(
        address[] calldata users,
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes32[][] calldata proofs,
        address[] calldata recipients,
        uint256[] calldata chainIds
    ) external {
        _claim(users, tokens, amounts, proofs, recipients, chainIds);
    }

    /// @notice Returns the Merkle root that is currently live for the contract
    function getMerkleRoot() public view returns (bytes32) {
        return tree.merkleRoot;
    }

    /*//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                 OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////*/

    /// @notice Updates the Merkle tree
    function updateTree(MerkleTree calldata _tree) external onlyOwner {
        tree = _tree;
        emit TreeUpdated(_tree.merkleRoot, _tree.ipfsHash);
    }

    /// @notice Transfers ownership of the contract to a new account
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /// @notice Recovers any ERC20 token left on the contract
    function recoverERC20(
        address tokenAddress,
        address to,
        uint256 amountToRecover
    ) external onlyOwner {
        IERC20(tokenAddress).safeTransfer(to, amountToRecover);
        emit Recovered(tokenAddress, to, amountToRecover);
    }

    /*//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                   INTERNAL HELPERS
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////*/

    /// @notice Internal version of `claimWithRecipient`
    function _claim(
        address[] calldata users,
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes32[][] calldata proofs,
        address[] memory recipients,
        uint256[] calldata chainIds
    ) internal nonReentrant {
        uint256 usersLength = users.length;
        if (
            usersLength == 0 ||
            usersLength != tokens.length ||
            usersLength != amounts.length ||
            usersLength != proofs.length ||
            usersLength != recipients.length ||
            usersLength != chainIds.length
        ) revert InvalidLengths();

        for (uint256 i; i < usersLength; ) {
            address user = users[i];
            address token = tokens[i];
            uint256 amount = amounts[i];
            uint256 chainId = chainIds[i];

            require(msg.sender == user, "Not user");

            // Verifying proof
            bytes32 leaf = keccak256(abi.encode(user, token, amount));
            if (!_verifyProof(leaf, proofs[i])) revert InvalidProof();

            // Closing reentrancy gate here
            uint256 toSend = amount - claimed[user][token].amount;
            claimed[user][token] = Claim(
                SafeCast.toUint208(amount),
                uint48(block.timestamp),
                getMerkleRoot()
            );
            emit Claimed(user, token, toSend);

            address recipient = recipients[i];
            // Only `msg.sender` can set a different recipient for itself within the context of a call to claim
            // The recipient set in the context of the call to `claim` can override the default recipient set by the user
            if (recipient == address(0)) {
                recipient = user;
            }

            if (toSend != 0) {
                if (block.chainid == chainId) {
                    IERC20(token).safeTransfer(recipient, toSend);
                } else {
                    // Send the Token to the bridge for cross-chain transfer
                    SuperchainTokenBridge(Predeploys.SUPERCHAIN_TOKEN_BRIDGE)
                        .sendERC20(token, recipient, toSend, chainId);
                }
            }
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Checks the validity of a proof
    /// @param leaf Hashed leaf data, the starting point of the proof
    /// @param proof Array of hashes forming a hash chain from leaf to root
    /// @return true If proof is correct, else false
    function _verifyProof(
        bytes32 leaf,
        bytes32[] memory proof
    ) internal view returns (bool) {
        bytes32 currentHash = leaf;
        uint256 proofLength = proof.length;
        for (uint256 i; i < proofLength; ) {
            if (currentHash < proof[i]) {
                currentHash = keccak256(abi.encode(currentHash, proof[i]));
            } else {
                currentHash = keccak256(abi.encode(proof[i], currentHash));
            }
            unchecked {
                ++i;
            }
        }
        bytes32 root = getMerkleRoot();
        if (root == bytes32(0)) revert InvalidUninitializedRoot();
        return currentHash == root;
    }
}
