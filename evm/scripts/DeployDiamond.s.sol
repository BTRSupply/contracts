// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {ICreateX} from "@interfaces/ICreateX.sol";
import {DiamondDeployer} from "@utils/generated/DiamondDeployer.gen.sol";

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
        address treasury = vm.envOr("TREASURY", address(0x1234));
        
        console2.log("Deploying BTR Diamond with admin:", admin);
        console2.log("Treasury address:", treasury);
        
        vm.startBroadcast(deployerPk);

        // Deploy diamond and all facets using the utility
        DiamondDeployer diamondDeployer = new DiamondDeployer();
        DiamondDeployer.Deployment memory deployment = diamondDeployer.deployDiamond(admin, treasury);
        
        vm.stopBroadcast();
        
        // Print deployment summary
        console2.log("=========== Deployment Summary ===========");
        console2.log("Diamond address:          ", address(deployment.diamond));
        
        // Access facets by index, using the expected order from the deployment script
        // The facet types are described in the facetNames array
        for (uint i = 0; i < deployment.facets.length && i < deployment.facetNames.length; i++) {
            console2.log(string(abi.encodePacked(deployment.facetNames[i], " address:")), deployment.facets[i]);
        }

        console2.log("Admin address:            ", admin);
        console2.log("=========================================");
    }
} 