// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {CampaignCreator} from "../src/CampaignCreator.sol";
import {console} from "forge-std/console.sol";

contract DeployCampaignCreator is Script {
    function run() external {
        address distributor = 0xB1b65D1B309e677352478Eb11F65D16b72F176aD;
        address owner = 0x2B30bC9F81f919B01a09d5A3De574B15eAF2C3BC;

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        // Deploy the CampaignCreator contract with the Distributor address
        CampaignCreator campaignCreator = new CampaignCreator(
            owner,
            distributor
        );
        console.log("CampaignCreator", address(campaignCreator));
    }
}

// 0x4e4077cD98ebd0Ab4f2A034BE823E5943c7fb378
