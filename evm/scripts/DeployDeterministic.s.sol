// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {ICreateX} from "@interfaces/ICreateX.sol";
import {BTRDiamond} from "@/BTRDiamond.sol";
import {DiamondCutFacet} from "@facets/DiamondCutFacet.sol";
import {DiamondDeployer} from "@utils/generated/DiamondDeployer.gen.sol";

/**
 * @title DeployDeterministic
 * @notice Example script showing how to use DiamondDeployer for deterministic deployment
 */
contract DeployDeterministic is Script {
    // CreateX contract on mainnet
    address constant CREATEX = 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed;

    function run() external {
        // Get deployer private key and address
        uint256 deployerPk = vm.envUint("DEPLOYER_PK");
        address deployer = vm.addr(deployerPk);
        address admin = deployer;
        
        // Create CreateX instance
        ICreateX createX = ICreateX(CREATEX);
        
        // Create DiamondDeployer instance
        DiamondDeployer diamondDeployer = new DiamondDeployer();
        
        // Define salts for each contract
        DiamondDeployer.Salts memory salts;
        salts.diamond = keccak256(bytes("btr.diamond.v1"));
        salts.diamond_cut = keccak256(bytes("btr.diamondCut.v1"));
        // Leave other salts as bytes32(0) to use default generation
        
        // Predict addresses
        DiamondDeployer.DeploymentAddresses memory predicted = diamondDeployer.predictDeterministicAddresses(
            salts,
            "btr", // Prefix for default salt generation
            deployer,
            createX
        );
        
        console2.log("Deployer address:", deployer);
        console2.log("Predicted DiamondCutFacet address:", predicted.diamond_cut);
        console2.log("Predicted Diamond address:", predicted.diamond);
        
        // Demonstrate that a different deployer would get different addresses
        address anotherDeployer = address(0x123456);
        DiamondDeployer.DeploymentAddresses memory anotherPredicted = diamondDeployer.predictDeterministicAddresses(
            salts,
            "btr",
            anotherDeployer,
            createX
        );
        
        console2.log("Another deployer:", anotherDeployer);
        console2.log("Another deployer's DiamondCutFacet address:", anotherPredicted.diamond_cut);
        console2.log("Another deployer's Diamond address:", anotherPredicted.diamond);
        
        // Start actual deployment
        vm.startBroadcast(deployerPk);
        
        // Deploy deterministically
        DiamondDeployer.DeploymentAddresses memory deployed = diamondDeployer.deployDeterministic(
            admin,
            salts,
            "btr",
            createX
        );
        
        vm.stopBroadcast();
        
        // Verify addresses match predictions
        console2.log("Actual DiamondCutFacet address:", deployed.diamond_cut);
        console2.log("Actual Diamond address:", deployed.diamond);
        
        require(deployed.diamond_cut == predicted.diamond_cut, "DiamondCutFacet address mismatch");
        require(deployed.diamond == predicted.diamond, "Diamond address mismatch");
        
        // Confirm addresses are different from other deployer's addresses
        require(deployed.diamond_cut != anotherPredicted.diamond_cut, "Addresses should be different for different deployers");
        require(deployed.diamond != anotherPredicted.diamond, "Addresses should be different for different deployers");
    }
} 