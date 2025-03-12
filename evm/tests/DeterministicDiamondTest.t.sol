// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {ICreateX} from "../interfaces/ICreateX.sol";
import {IDiamondLoupe} from "../interfaces/IDiamondLoupe.sol";
import {IDiamondCut} from "../interfaces/IDiamondCut.sol";
import {AccessControlFacet} from "../facets/AccessControlFacet.sol";
import {LibAccessControl} from "../libraries/LibAccessControl.sol";
import {DiamondCutFacet} from "../facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../facets/DiamondLoupeFacet.sol";
import {BTRDiamond} from "../BTRDiamond.sol";
import {DiamondDeployer} from "../utils/DiamondDeployer.sol";

contract DeterministicDiamondTest is Test {
    // CreateX contract on mainnet
    address constant CREATEX = 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed;
    ICreateX createX;
    DiamondDeployer deployer;
    
    BTRDiamond diamond;
    DiamondCutFacet diamondCutFacet;
    DiamondLoupeFacet diamondLoupeFacet;
    AccessControlFacet accessControlFacet;
    
    address admin;
    
    bytes32 constant DIAMOND_SALT = bytes32(uint256(1));
    string constant FACET_SALT_PREFIX = "btr.diamond.test";
    
    function setUp() public {
        admin = address(this);
        createX = ICreateX(CREATEX);
        deployer = new DiamondDeployer();
        
        // First predict addresses using default salts
        DiamondDeployer.DeploymentAddresses memory predicted = deployer.predictDeterministicAddresses(
            FACET_SALT_PREFIX,
            DIAMOND_SALT,
            address(this),
            createX
        );
        
        // Log predicted addresses
        console.log("Predicted Diamond address:", predicted.diamond);
        console.log("Predicted DiamondCutFacet address:", predicted.diamondCutFacet);
        console.log("Predicted DiamondLoupeFacet address:", predicted.diamondLoupeFacet);
        console.log("Predicted AccessControlFacet address:", predicted.accessControlFacet);
        console.log("Predicted DiamondInit address:", predicted.diamondInit);
        
        // Deploy deterministically using default salts
        DiamondDeployer.DeploymentAddresses memory deployed = deployer.deployDeterministic(
            admin,
            DIAMOND_SALT,
            FACET_SALT_PREFIX,
            createX
        );
        
        // Cast addresses to their respective types
        diamond = BTRDiamond(payable(deployed.diamond));
        diamondCutFacet = DiamondCutFacet(deployed.diamondCutFacet);
        diamondLoupeFacet = DiamondLoupeFacet(deployed.diamondLoupeFacet);
        accessControlFacet = AccessControlFacet(deployed.accessControlFacet);
        
        // Log actual addresses
        console.log("Actual Diamond address:", deployed.diamond);
        console.log("Actual DiamondCutFacet address:", deployed.diamondCutFacet);
        console.log("Actual DiamondLoupeFacet address:", deployed.diamondLoupeFacet);
        console.log("Actual AccessControlFacet address:", deployed.accessControlFacet);
        console.log("Actual DiamondInit address:", deployed.diamondInit);
    }

    function testDeterministicAddresses() public {
        // Test that predicted addresses match actual addresses
        DiamondDeployer.DeploymentAddresses memory predicted = deployer.predictDeterministicAddresses(
            FACET_SALT_PREFIX,
            DIAMOND_SALT,
            address(this),
            createX
        );
        
        assertEq(address(diamond), predicted.diamond, "Diamond address mismatch");
        assertEq(address(diamondCutFacet), predicted.diamondCutFacet, "DiamondCutFacet address mismatch");
        assertEq(address(diamondLoupeFacet), predicted.diamondLoupeFacet, "DiamondLoupeFacet address mismatch");
        assertEq(address(accessControlFacet), predicted.accessControlFacet, "AccessControlFacet address mismatch");
    }

    function testCustomSalts() public {
        // Create custom salts
        DiamondDeployer.Salts memory customSalts;
        customSalts.diamond = keccak256(abi.encodePacked("custom.diamond"));
        customSalts.diamondCut = keccak256(abi.encodePacked("custom.diamondCut"));
        customSalts.diamondLoupe = keccak256(abi.encodePacked("custom.diamondLoupe"));
        customSalts.accessControl = keccak256(abi.encodePacked("custom.accessControl"));
        customSalts.init = keccak256(abi.encodePacked("custom.init"));
        
        // Predict addresses with custom salts
        DiamondDeployer.DeploymentAddresses memory predicted = deployer.predictDeterministicAddresses(
            customSalts,
            "unused-prefix", // Prefix is unused when custom salts are provided
            address(this),
            createX
        );
        
        // Log predicted addresses with custom salts
        console.log("Custom Diamond address:", predicted.diamond);
        console.log("Custom DiamondCutFacet address:", predicted.diamondCutFacet);
        console.log("Custom DiamondLoupeFacet address:", predicted.diamondLoupeFacet);
        console.log("Custom AccessControlFacet address:", predicted.accessControlFacet);
        console.log("Custom DiamondInit address:", predicted.diamondInit);
        
        // Verify that custom salts produce different addresses
        assertTrue(predicted.diamond != address(diamond), "Custom salt should produce different diamond address");
    }

    function testMixedSalts() public {
        // Create mixed salts (some custom, some default)
        DiamondDeployer.Salts memory mixedSalts;
        mixedSalts.diamond = keccak256(abi.encodePacked("custom.diamond"));
        // diamondCut will use default
        mixedSalts.diamondLoupe = keccak256(abi.encodePacked("custom.diamondLoupe"));
        // accessControl will use default
        mixedSalts.init = keccak256(abi.encodePacked("custom.init"));
        
        // Predict addresses with mixed salts
        DiamondDeployer.DeploymentAddresses memory predicted = deployer.predictDeterministicAddresses(
            mixedSalts,
            FACET_SALT_PREFIX,
            address(this),
            createX
        );
        
        // Log predicted addresses with mixed salts
        console.log("Mixed Diamond address:", predicted.diamond);
        console.log("Mixed DiamondCutFacet address:", predicted.diamondCutFacet);
        console.log("Mixed DiamondLoupeFacet address:", predicted.diamondLoupeFacet);
        console.log("Mixed AccessControlFacet address:", predicted.accessControlFacet);
        console.log("Mixed DiamondInit address:", predicted.diamondInit);
        
        // Verify that the diamond address is different but diamondCut is the same
        assertTrue(predicted.diamond != address(diamond), "Custom diamond salt should produce different address");
        assertEq(predicted.diamondCutFacet, address(diamondCutFacet), "Default diamondCut salt should produce same address");
    }

    function testDiamondFunctionality() public {
        // Test that the diamond has the expected facets
        address[] memory facetAddresses = IDiamondLoupe(address(diamond)).facetAddresses();
        assertEq(facetAddresses.length, 3, "Should have 3 facets"); // DiamondCutFacet + DiamondLoupeFacet + AccessControlFacet
        
        // Test access control functionality
        AccessControlFacet ac = AccessControlFacet(address(diamond));
        assertTrue(ac.hasRole(LibAccessControl.ADMIN_ROLE, admin), "Admin should have admin role");
        
        // Test adding a new facet
        // This isn't really necessary for this test, but demonstrates that the diamond works
        address newManager = address(0x123);
        ac.grantRole(LibAccessControl.MANAGER_ROLE, newManager);
        assertTrue(ac.hasRole(LibAccessControl.MANAGER_ROLE, newManager), "New manager should have manager role");
    }

    function testConsistentAddresses() public {
        // Create another deployer and check that it predicts the same addresses
        DiamondDeployer otherDeployer = new DiamondDeployer();
        
        DiamondDeployer.DeploymentAddresses memory predicted = otherDeployer.predictDeterministicAddresses(
            FACET_SALT_PREFIX,
            DIAMOND_SALT,
            address(this),
            createX
        );
        
        assertEq(predicted.diamond, address(diamond), "Diamond address should be predictable from another deployer");
    }
    
    function testRedeployReverts() public {
        // Try to deploy again with the same salts - should revert
        vm.expectRevert(); // Should revert with CREATE3 deployment failed
        deployer.deployDeterministic(admin, DIAMOND_SALT, FACET_SALT_PREFIX, createX);
    }
}
