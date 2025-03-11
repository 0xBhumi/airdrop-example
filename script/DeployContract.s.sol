// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {Distributor} from "../src/Distributor.sol";
import {console} from "forge-std/console.sol";

contract DeployContract is Script {
    function run() external {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        Distributor distributor = new Distributor{salt: "TriggerX"}(
            0x88826a677aDB340F0c7b8CCd6aF6aD96a40b0085
        );
        vm.stopBroadcast();

        console.log("distributor address", address(distributor));
    }
}
