// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {Distributor} from "../src/Distributor.sol";
import {console} from "forge-std/console.sol";

contract DeployCampaignCreator is Script {
    function run() external {
        address owner = 0x2B30bC9F81f919B01a09d5A3De574B15eAF2C3BC;

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        // Deploy the Distributor contract
        Distributor distributor = new Distributor{salt: "TriggerX"}(owner);
        vm.stopBroadcast();

        console.log("distributor address", address(distributor));
    }
}

// 0xB1b65D1B309e677352478Eb11F65D16b72F176aD
