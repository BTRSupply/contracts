// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import {DiamondDeployer} from "@utils/generated/DiamondDeployer.gen.sol";
import {LibAccessControl} from "@libraries/LibAccessControl.sol";

contract DeployDiamondScript is Script {
    function setUp() public {}

    function run() public {
        // Get admin from env or use msg.sender
        address admin = vm.envOr("DEPLOYER", msg.sender);
        address treasury = vm.envOr("TREASURY", address(0x1234));
        
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);
        
        // For quick local deployments
        // vm.startBroadcast();
        
        // Deploy diamond and its facets
        DiamondDeployer diamondDeployer = new DiamondDeployer();
        DiamondDeployer.Deployment memory deployment = diamondDeployer.deployDiamond(admin, treasury);
        
        vm.stopBroadcast();
        
        // Log deployment information
        console.log("Diamond deployed at: %s", deployment.diamond);
        console.log("Facets deployed:");
        for (uint i = 0; i < deployment.facets.length; i++) {
            console.log("  %s: %s", deployment.facetNames[i], deployment.facets[i]);
        }
    }
} 