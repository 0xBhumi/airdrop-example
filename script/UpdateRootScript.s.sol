// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {Distributor, MerkleTree} from "../src/Distributor.sol";
import {console} from "forge-std/console.sol";
import {SuperchainERC20} from "@contracts-bedrock/src/L2/SuperchainERC20.sol";

contract UpdateRootScript is Script {
    address constant DISTRIBUTOR = 0xB1b65D1B309e677352478Eb11F65D16b72F176aD;

    function run() external {
        MerkleTree memory tree = MerkleTree({
            merkleRoot: 0xf4b63c0363b230d218497ae1abdb841ffa39ebf36ba1c19840ed2e524896bed1,
            ipfsHash: 0x516d4578616d706c654861736800000000000000000000000000000000000000
        });

        vm.startBroadcast(vm.envUint("OWNER_PRIVATE_KEY"));

        // Approve token
        Distributor(DISTRIBUTOR).updateTree(tree);

        vm.stopBroadcast();
    }
}
