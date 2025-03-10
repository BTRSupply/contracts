// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {CREATE3} from "./Create3.sol";

/**
 * @title DeterministicDeployer
 * @notice Minimal utility for deploying any contract to a deterministic address using Solady's CREATE3
 * @dev Incorporates deployer address in salt calculation to ensure address uniqueness per deployer
 */
contract DeterministicDeployer {
    /**
     * @notice Deploy a contract deterministically using CREATE3
     * @param creationCode The contract creation code (bytecode + constructor args)
     * @param salt Unique salt for deterministic address generation
     * @return deployed The address of the deployed contract
     */
    function deploy(bytes memory creationCode, bytes32 salt) external returns (address deployed) {
        // Combine msg.sender with salt to make it deployer-specific
        bytes32 deployerSpecificSalt = _computeDeployerSpecificSalt(salt);
        return CREATE3.deployDeterministic(creationCode, deployerSpecificSalt);
    }

    /**
     * @notice Deploy a contract deterministically with ETH value using CREATE3
     * @param creationCode The contract creation code (bytecode + constructor args)
     * @param salt Unique salt for deterministic address generation
     * @param value ETH value to send with deployment
     * @return deployed The address of the deployed contract
     */
    function deployWithValue(bytes memory creationCode, bytes32 salt, uint256 value) external payable returns (address deployed) {
        require(msg.value >= value, "Insufficient ETH provided");
        // Combine msg.sender with salt to make it deployer-specific
        bytes32 deployerSpecificSalt = _computeDeployerSpecificSalt(salt);
        return CREATE3.deployDeterministic(value, creationCode, deployerSpecificSalt);
    }
    
    /**
     * @notice Predict the deterministic address for a given salt and deployer
     * @param salt Unique salt for deterministic address generation
     * @param deployer The address that will deploy the contract (defaults to msg.sender)
     * @return predictedAddress The address where the contract would be deployed
     */
    function predictAddress(bytes32 salt, address deployer) external view returns (address predictedAddress) {
        // Default to msg.sender if no deployer is specified
        if (deployer == address(0)) {
            deployer = msg.sender;
        }
        
        // Compute deployer-specific salt
        bytes32 deployerSpecificSalt = keccak256(abi.encodePacked(salt, deployer));
        return CREATE3.predictDeterministicAddress(deployerSpecificSalt);
    }
    
    /**
     * @notice Predict the deterministic address for a given salt and msg.sender as deployer
     * @param salt Unique salt for deterministic address generation
     * @return predictedAddress The address where the contract would be deployed
     */
    function predictAddress(bytes32 salt) external view returns (address predictedAddress) {
        return this.predictAddress(salt, msg.sender);
    }
    
    /**
     * @notice Helper to compute a deployment salt from a string
     * @param name Name/identifier to use for salt generation
     * @return computedSalt The generated salt
     */
    function computeSalt(string memory name) external pure returns (bytes32 computedSalt) {
        return keccak256(abi.encodePacked(name));
    }
    
    /**
     * @notice Compute a deployer-specific salt by combining the original salt with msg.sender
     * @param salt The original salt
     * @return deployerSpecificSalt The salt combined with the deployer address
     */
    function _computeDeployerSpecificSalt(bytes32 salt) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(salt, msg.sender));
    }
}
