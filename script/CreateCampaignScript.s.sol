// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {CampaignCreator, CampaignParameters} from "../src/CampaignCreator.sol";
import {console} from "forge-std/console.sol";
import {SuperchainERC20} from "@contracts-bedrock/src/L2/SuperchainERC20.sol";

contract CreateCampaignScript is Script {
    address constant CREATOR = 0xB4e6ee231C86bBcCB35935244CBE9cE333D30Bdf;
    address constant REWARDTOKEN = 0x4200000000000000000000000000000000000024;
    address constant CAMPAIGN = 0x4e4077cD98ebd0Ab4f2A034BE823E5943c7fb378;
    uint256 constant REWARD_AMOUNT = 0.001 ether;

    function run() external {
        // Create a new campaign
        CampaignParameters memory newCampaign = CampaignParameters({
            campaignId: bytes32(0), // This will be set by the contract
            creator: CREATOR,
            rewardToken: REWARDTOKEN,
            amount: REWARD_AMOUNT,
            campaignType: 1, // Example campaign type
            startTimestamp: uint32(block.timestamp),
            duration: 3600, // 1 hour
            campaignData: bytes("example campaign data")
        });

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        // Approve token
        SuperchainERC20(REWARDTOKEN).approve(CAMPAIGN, REWARD_AMOUNT);

        // Create the campaign and get the campaignId
        bytes32 campaignId = CampaignCreator(CAMPAIGN).createCampaign(
            newCampaign
        );

        vm.stopBroadcast();
    }
}
