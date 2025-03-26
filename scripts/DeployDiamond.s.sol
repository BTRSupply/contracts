// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import {DiamondDeployer} from "@utils/generated/DiamondDeployer.gen.sol";
import {LibAccessControl} from "@libraries/LibAccessControl.sol";

contract DeployDiamondScript is Script {
    function setUp() public {}

    function run() public {
        // Get deployer from env variable
        uint256 deployerPk = vm.envUint("DEPLOYER_PK");
        address deployer = vm.addr(deployerPk);
        address treasury = vm.envOr("TREASURY", address(0));
        
        if (treasury == address(0)) {
            console.log("Warning: Using zero address for treasury. Set TREASURY environment variable.");
        }
        
        vm.startBroadcast(deployerPk);
        
        // Deploy diamond and its facets
        DiamondDeployer diamondDeployer = new DiamondDeployer();
        DiamondDeployer.Deployment memory deployment = diamondDeployer.deployDiamond(deployer, treasury);
        
        vm.stopBroadcast();
        
        // Log deployment information
        console.log("Diamond deployed at: %s", deployment.diamond);
        console.log("Facets deployed:");
        for (uint i = 0; i < deployment.facets.length; i++) {
            console.log("  %s: %s", deployment.facetNames[i], deployment.facets[i]);
        }
    }
} 