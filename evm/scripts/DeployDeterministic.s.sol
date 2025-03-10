// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {DeterministicDeployer} from "../utils/DeterministicDeployer.sol";
import {BTRDiamond} from "../BTRDiamond.sol";
import {DiamondCutFacet} from "../facets/DiamondCutFacet.sol";

/**
 * @title DeployDeterministic
 * @notice Example script showing how to use DeterministicDeployer for any contract
 */
contract DeployDeterministic is Script {
    function run() external {
        // Get deployer private key and address
        uint256 deployerPk = vm.envUint("DEPLOYER_PK");
        address deployer = vm.addr(deployerPk);
        address admin = deployer;
        
        // Create deployer instance
        DeterministicDeployer deterministicDeployer = new DeterministicDeployer();
        
        // Define salts for each contract
        bytes32 diamondCutSalt = deterministicDeployer.computeSalt("btr.diamondCut.v1");
        bytes32 diamondSalt = deterministicDeployer.computeSalt("btr.diamond.v1");
        
        // Predict addresses - these will be unique to the deployer
        address predictedDiamondCutAddress = deterministicDeployer.predictAddress(diamondCutSalt, deployer);
        address predictedDiamondAddress = deterministicDeployer.predictAddress(diamondSalt, deployer);
        
        console2.log("Deployer address:", deployer);
        console2.log("Predicted DiamondCutFacet address:", predictedDiamondCutAddress);
        console2.log("Predicted Diamond address:", predictedDiamondAddress);
        
        // Demonstrate that a different deployer would get different addresses
        address anotherDeployer = address(0x123456);
        address anotherDiamondCutAddress = deterministicDeployer.predictAddress(diamondCutSalt, anotherDeployer);
        address anotherDiamondAddress = deterministicDeployer.predictAddress(diamondSalt, anotherDeployer);
        
        console2.log("Another deployer:", anotherDeployer);
        console2.log("Another deployer's DiamondCutFacet address:", anotherDiamondCutAddress);
        console2.log("Another deployer's Diamond address:", anotherDiamondAddress);
        
        // Start actual deployment
        vm.startBroadcast(deployerPk);
        
        // Deploy DiamondCutFacet
        address diamondCutFacet = deterministicDeployer.deploy(
            type(DiamondCutFacet).creationCode,
            diamondCutSalt
        );
        
        // Prepare creation code for Diamond (including constructor args)
        bytes memory diamondCreationCode = abi.encodePacked(
            type(BTRDiamond).creationCode, 
            abi.encode(admin, diamondCutFacet)
        );
        
        // Deploy Diamond
        address diamond = deterministicDeployer.deploy(
            diamondCreationCode,
            diamondSalt
        );
        
        vm.stopBroadcast();
        
        // Verify addresses match predictions
        console2.log("Actual DiamondCutFacet address:", diamondCutFacet);
        console2.log("Actual Diamond address:", diamond);
        
        require(diamondCutFacet == predictedDiamondCutAddress, "DiamondCutFacet address mismatch");
        require(diamond == predictedDiamondAddress, "Diamond address mismatch");
        
        // Confirm addresses are different from other deployer's addresses
        require(diamondCutFacet != anotherDiamondCutAddress, "Addresses should be different for different deployers");
        require(diamond != anotherDiamondAddress, "Addresses should be different for different deployers");
    }
} 