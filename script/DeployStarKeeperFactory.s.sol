// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {StarKeeperFactory} from "../src/StarKeeperFactory.sol";

contract DeployStarKeeperFactory is Script {
    function run() external returns (StarKeeperFactory) {
        vm.startBroadcast();

        console.log("Deploying StarKeeperFactory contract...");
        console.log("Deployer (initial admin):", msg.sender);

        // Create initial admins array with deployer as first admin
        address[] memory initialAdmins = new address[](1);
        initialAdmins[0] = msg.sender;

        StarKeeperFactory starKeeperFactory = new StarKeeperFactory(initialAdmins);

        console.log("StarKeeperFactory deployed at:", address(starKeeperFactory));
        console.log("Initial admin count: 1");
        console.log("Quorum threshold: 1 (75% of 1 admin)");

        vm.stopBroadcast();
        return starKeeperFactory;
    }

    // Alternative deployment with multiple initial admins
    function runWithMultipleAdmins(address[] memory _initialAdmins) external returns (StarKeeperFactory) {
        require(_initialAdmins.length > 0, "At least one admin required");

        vm.startBroadcast();

        console.log("Deploying StarKeeperFactory with multiple admins...");
        console.log("Admin count: Multiple admins provided");

        // Log all initial admins
        for (uint256 i = 0; i < _initialAdmins.length; i++) {
            console.log("Admin", i, ":");
            console.log(_initialAdmins[i]);
        }

        StarKeeperFactory starKeeperFactory = new StarKeeperFactory(_initialAdmins);

        console.log("StarKeeperFactory deployed at:", address(starKeeperFactory));

        console.log("Quorum threshold calculated for 75% governance");

        vm.stopBroadcast();
        return starKeeperFactory;
    }
}
