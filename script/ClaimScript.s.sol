// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {Distributor, ClaimData} from "../src/Distributor.sol";
import {console} from "forge-std/console.sol";
import {SuperchainERC20} from "@contracts-bedrock/src/L2/SuperchainERC20.sol";

contract ClaimScript is Script {
    address constant DISTRIBUTOR = 0xB1b65D1B309e677352478Eb11F65D16b72F176aD;
    address constant USER = 0x18e23191359F9Dc403Ba2942b87a896535c935C4;
    address constant REWARDTOKEN = 0x4200000000000000000000000000000000000024;
    uint256 constant CLAIM_AMOUNT = 0.00005 ether;

    function run() external {
        // Prepare claim parameters
        address[] memory users = new address[](1);
        users[0] = USER;

        address[] memory tokens = new address[](1);
        tokens[0] = REWARDTOKEN;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = CLAIM_AMOUNT;

        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = new bytes32[](1);
        proofs[0][
            0
        ] = 0x640b9d8fd6aa01dababa3ad64f0b999a20427de7991653763cabbb1249eae0b4;

        address[] memory recipients = new address[](1);
        recipients[0] = USER;

        uint256[] memory chainIds = new uint256[](1);
        chainIds[0] = 420120001; // Use the current chain ID

        ClaimData memory claimData = ClaimData({
            users: users,
            tokens: tokens,
            amounts: amounts,
            proofs: proofs,
            recipients: recipients,
            chainIds: chainIds
        });

        vm.startBroadcast(vm.envUint("USER_PRIVATE_KEY"));

        // Approve token
        Distributor(DISTRIBUTOR).claim(claimData);

        vm.stopBroadcast();
    }
}
