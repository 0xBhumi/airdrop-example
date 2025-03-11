// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IL2ToL2CrossDomainMessenger} from "@contracts-bedrock/interfaces/L2/IL2ToL2CrossDomainMessenger.sol";
import {Predeploys} from "@contracts-bedrock/src/libraries/Predeploys.sol";

struct ClaimData {
    address[] users;
    address[] tokens;
    uint256[] amounts;
    bytes32[][] proofs;
    address[] recipients;
    uint256[] chainIds;
}

contract Spoke {
    // Immutable reference to the L2 CrossDomainMessenger
    IL2ToL2CrossDomainMessenger internal immutable messenger;

    /*//////////////////////////////////////////////////////////////////////////////////////////////////////////////////
                                                      CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////*/

    constructor() {
        messenger = IL2ToL2CrossDomainMessenger(
            Predeploys.L2_TO_L2_CROSS_DOMAIN_MESSENGER
        );
    }

    /// @notice Claims rewards for a given set of users
    /// @dev Unless another address has been approved for claiming, only an address can claim for itself
    function claim(ClaimData calldata data) external {
        messenger.sendMessage(
            901,
            address(this),
            abi.encodeCall(this._claim, (data))
        );
    }

    function _claim(ClaimData calldata data) external {}
}
