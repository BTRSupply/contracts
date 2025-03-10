// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {DeterministicDiamondDeployer} from "../utils/DeterministicDiamondDeployer.sol";
import {IDiamondLoupe} from "../interfaces/IDiamondLoupe.sol";
import {IDiamondCut} from "../interfaces/IDiamondCut.sol";
import {AccessControlFacet} from "../facets/AccessControlFacet.sol";
import {LibAccessControl} from "../libraries/LibAccessControl.sol";

contract DeterministicDiamondTest is Test {
    DeterministicDiamondDeployer deployer;
    DeterministicDiamondDeployer.Deployment deployment;
    address admin;
    
    bytes32 constant DIAMOND_SALT = bytes32(uint256(1));
    string constant FACET_SALT_PREFIX = "btr.diamond.test";
    
    function setUp() public {
        admin = address(this);
        deployer = new DeterministicDiamondDeployer();
        
        // First predict addresses
        (
            address predictedDiamond,
            address predictedDiamondCutFacet,
            address predictedDiamondLoupeFacet,
            address predictedAccessControlFacet,
            address predictedDiamondInit
        ) = deployer.predictDeterministicAddresses(FACET_SALT_PREFIX, DIAMOND_SALT);
        
        // Log predicted addresses
        console.log("Predicted Diamond address:", predictedDiamond);
        console.log("Predicted DiamondCutFacet address:", predictedDiamondCutFacet);
        console.log("Predicted DiamondLoupeFacet address:", predictedDiamondLoupeFacet);
        console.log("Predicted AccessControlFacet address:", predictedAccessControlFacet);
        console.log("Predicted DiamondInit address:", predictedDiamondInit);
        
        // Deploy deterministically
        deployment = deployer.deployDeterministic(admin, DIAMOND_SALT, FACET_SALT_PREFIX);
        
        // Log actual addresses
        console.log("Actual Diamond address:", address(deployment.diamond));
        console.log("Actual DiamondCutFacet address:", address(deployment.diamondCutFacet));
        console.log("Actual DiamondLoupeFacet address:", address(deployment.diamondLoupeFacet));
        console.log("Actual AccessControlFacet address:", address(deployment.accessControlFacet));
        console.log("Actual DiamondInit address:", address(deployment.diamondInit));
    }

    function testDeterministicAddresses() public {
        // Test that predicted addresses match actual addresses
        (
            address predictedDiamond,
            address predictedDiamondCutFacet,
            address predictedDiamondLoupeFacet,
            address predictedAccessControlFacet,
            address predictedDiamondInit
        ) = deployer.predictDeterministicAddresses(FACET_SALT_PREFIX, DIAMOND_SALT);
        
        assertEq(address(deployment.diamond), predictedDiamond, "Diamond address mismatch");
        assertEq(address(deployment.diamondCutFacet), predictedDiamondCutFacet, "DiamondCutFacet address mismatch");
        assertEq(address(deployment.diamondLoupeFacet), predictedDiamondLoupeFacet, "DiamondLoupeFacet address mismatch");
        assertEq(address(deployment.accessControlFacet), predictedAccessControlFacet, "AccessControlFacet address mismatch");
        assertEq(address(deployment.diamondInit), predictedDiamondInit, "DiamondInit address mismatch");
    }

    function testDiamondFunctionality() public {
        // Test that the diamond has the expected facets
        address[] memory facetAddresses = IDiamondLoupe(address(deployment.diamond)).facetAddresses();
        assertEq(facetAddresses.length, 3, "Should have 3 facets"); // DiamondCutFacet + DiamondLoupeFacet + AccessControlFacet
        
        // Test access control functionality
        AccessControlFacet ac = AccessControlFacet(address(deployment.diamond));
        assertTrue(ac.hasRole(LibAccessControl.ADMIN_ROLE, admin), "Admin should have admin role");
        
        // Test adding a new facet
        // This isn't really necessary for this test, but demonstrates that the diamond works
        address newManager = address(0x123);
        ac.grantRole(LibAccessControl.MANAGER_ROLE, newManager);
        assertTrue(ac.hasRole(LibAccessControl.MANAGER_ROLE, newManager), "New manager should have manager role");
    }

    function testConsistentAddresses() public {
        // Create another deployer and check that it predicts the same addresses
        DeterministicDiamondDeployer anotherDeployer = new DeterministicDiamondDeployer();
        
        (
            address predictedDiamond,
            address predictedDiamondCutFacet,
            address predictedDiamondLoupeFacet,
            address predictedAccessControlFacet,
            address predictedDiamondInit
        ) = anotherDeployer.predictDeterministicAddresses(FACET_SALT_PREFIX, DIAMOND_SALT);
        
        assertEq(address(deployment.diamond), predictedDiamond, "Diamond address should be predictable from another deployer");
        assertEq(address(deployment.diamondCutFacet), predictedDiamondCutFacet, "DiamondCutFacet address should be predictable from another deployer");
        assertEq(address(deployment.diamondLoupeFacet), predictedDiamondLoupeFacet, "DiamondLoupeFacet address should be predictable from another deployer");
        assertEq(address(deployment.accessControlFacet), predictedAccessControlFacet, "AccessControlFacet address should be predictable from another deployer");
        assertEq(address(deployment.diamondInit), predictedDiamondInit, "DiamondInit address should be predictable from another deployer");
    }
    
    function testRedeployReverts() public {
        // Try to deploy again with the same salts - should revert
        vm.expectRevert(); // CREATE3.DeploymentFailed.selector
        deployer.deployDeterministic(admin, DIAMOND_SALT, FACET_SALT_PREFIX);
    }
} 