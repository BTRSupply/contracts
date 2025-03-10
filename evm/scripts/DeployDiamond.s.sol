// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {DiamondDeployer} from "../utils/DiamondDeployer.sol";

/**
 * @title DeployDiamond
 * @notice Forge script to deploy BTR Diamond architecture
 */
contract DeployDiamond is Script {
    function run() external {
        // Get deployer private key and address
        uint256 deployerPk = vm.envUint("DEPLOYER_PK");
        address deployer = vm.addr(deployerPk);
        address admin = deployer;
        
        console2.log("Deploying BTR Diamond with admin:", admin);
        
        vm.startBroadcast(deployerPk);

        // Deploy diamond and all facets using the utility
        DiamondDeployer diamondDeployer = new DiamondDeployer();
        DiamondDeployer.Deployment memory deployment = diamondDeployer.deployDiamond(admin);
        
        vm.stopBroadcast();
        
        // Print deployment summary
        console2.log("=========== Deployment Summary ===========");
        console2.log("Diamond address:          ", address(deployment.diamond));
        console2.log("DiamondCutFacet address:  ", address(deployment.diamondCutFacet));
        console2.log("DiamondLoupeFacet address:", address(deployment.diamondLoupeFacet));
        console2.log("AccessControlFacet address:", address(deployment.accessControlFacet));
        console2.log("Admin address:            ", admin);
        console2.log("=========================================");
    }
} 