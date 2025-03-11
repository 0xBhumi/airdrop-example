// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import "../src/CampaignCreator.sol";
import "../src/Distributor.sol";
import "../src/MockERC20.sol";

contract DeployAndTest is Script {
    // Define constants for testing
    address constant CREATOR =
        address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266); // Campaign creator address
    address constant USER = address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8); // User who will claim rewards
    uint256 constant REWARD_AMOUNT = 1000 ether; // Total reward amount
    uint256 constant CLAIM_AMOUNT = 100 ether; // Amount to claim

    function run() external {
        uint256 op1Fork = vm.createSelectFork("http://127.0.0.1:9545");
        uint256 op2Fork = vm.createSelectFork("http://127.0.0.1:9546");

        vm.selectFork(op1Fork);
        // Start broadcasting transactions
        vm.startBroadcast();

        // Deploy a mock ERC20 token for testing
        MockERC20 rewardToken = new MockERC20{salt: "mocktoken"}(
            "RewardToken",
            "RTK"
        );
        console.log("RewardToken", address(rewardToken));

        // Deploy the Distributor contract
        Distributor distributor = new Distributor{salt: "distributor"}(
            0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
        );
        console.log("Distributor", address(distributor));

        // Deploy the CampaignCreator contract with the Distributor address
        CampaignCreator campaignCreator = new CampaignCreator(
            0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC,
            address(distributor)
        );
        console.log("CampaignCreator", address(campaignCreator));

        // Fund the creator with reward tokens
        rewardToken.mint(CREATOR, REWARD_AMOUNT);
        vm.stopBroadcast();
        // Create a new campaign
        CampaignParameters memory newCampaign = CampaignParameters({
            campaignId: bytes32(0), // This will be set by the contract
            creator: CREATOR,
            rewardToken: address(rewardToken),
            amount: REWARD_AMOUNT,
            campaignType: 1, // Example campaign type
            startTimestamp: uint32(block.timestamp),
            duration: 3600, // 1 hour
            campaignData: bytes("example campaign data")
        });

        // Approve the CampaignCreator to spend the reward tokens
        // vm.prank(CREATOR);
        vm.startBroadcast(
            0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
        );
        rewardToken.approve(address(campaignCreator), REWARD_AMOUNT);

        // Create the campaign and get the campaignId
        bytes32 campaignId = campaignCreator.createCampaign(newCampaign);

        // Validate that the campaign was created properly
        CampaignParameters memory createdCampaign = campaignCreator.campaign(
            campaignId
        );

        vm.stopBroadcast();

        require(
            rewardToken.balanceOf(address(distributor)) == REWARD_AMOUNT,
            "Reward amount not deposited"
        );
        require(
            createdCampaign.creator == CREATOR,
            "Campaign creator mismatch"
        );
        require(
            createdCampaign.rewardToken == address(rewardToken),
            "Reward token mismatch"
        );
        require(
            createdCampaign.amount == REWARD_AMOUNT,
            "Reward amount mismatch"
        );
        require(createdCampaign.duration == 3600, "Campaign duration mismatch");
        console.log(
            "Campaign created successfully with ID:",
            vm.toString(campaignId)
        );

        MerkleTree memory tree = MerkleTree({
            merkleRoot: 0x2101fe17014c844d94b4fd55b99f50a22429f1634b464533a17cbb4e2dd4a001,
            ipfsHash: 0x516d4578616d706c654861736800000000000000000000000000000000000000
        });

        vm.startBroadcast(
            0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a
        );

        distributor.updateTree(tree);

        vm.stopBroadcast();

        require(
            distributor.getMerkleRoot() ==
                0x2101fe17014c844d94b4fd55b99f50a22429f1634b464533a17cbb4e2dd4a001,
            "Merkle root mismatch"
        );

        // Simulate a claim process
        // Generate a mock Merkle proof (for testing purposes)
        // bytes32[] memory proof = new bytes32[](1);
        // proof[0] = keccak256(
        //     abi.encode(USER, address(rewardToken), CLAIM_AMOUNT)
        // );

        // Prepare claim parameters
        address[] memory users = new address[](1);
        users[0] = USER;

        address[] memory tokens = new address[](1);
        tokens[0] = address(rewardToken);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = CLAIM_AMOUNT;

        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = new bytes32[](2); // Initialize the inner array with 2 elements
        proofs[0][
            0
        ] = 0x4f6ad21c875c44e7f1fe4585f38213bba570c3a0b8dae2a8a8ec347e115323b7;
        proofs[0][
            1
        ] = 0x92644ec59205c91cd12fe05a6d6bb2d45e89e0213c06eb3382918a7f45498ee9;

        address[] memory recipients = new address[](1);
        recipients[0] = USER;

        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = block.chainid; // Use the current chain ID

        // // Claim the rewards
        // vm.prank(USER);

        vm.startBroadcast(
            0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
        );
        console.log("hello");
        distributor.claim(users, tokens, amounts, proofs, recipients, chainIds);

        vm.stopBroadcast();
        // // Validate that the claim was successful
        // uint256 userBalance = rewardToken.balanceOf(USER);
        // require(
        //     userBalance == CLAIM_AMOUNT,
        //     "Claim failed: Incorrect user balance"
        // );
        // console.log("User successfully claimed:", CLAIM_AMOUNT, "tokens");

        // Stop broadcasting transactions

        vm.selectFork(op2Fork);
        // Start broadcasting transactions
        vm.startBroadcast();

        // Deploy a mock ERC20 token for testing
        MockERC20 rewardTokenOnAnotherChain = new MockERC20{salt: "mocktoken"}(
            "RewardToken",
            "RTK"
        );
        console.log("RewardToken", address(rewardTokenOnAnotherChain));

        // Deploy the Distributor contract
        Distributor distributorOnAnotherChain = new Distributor{
            salt: "distributor"
        }(0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC);
        console.log("Distributor", address(distributorOnAnotherChain));

        vm.stopBroadcast();
    }
}
