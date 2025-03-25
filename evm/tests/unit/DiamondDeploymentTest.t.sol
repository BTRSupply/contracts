// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BaseTest} from "../BaseTest.t.sol";
import {AccessControlFacet} from "@facets/AccessControlFacet.sol";
import {IDiamondLoupe} from "@interfaces/IDiamond.sol";

contract DiamondDeploymentTest is BaseTest {
    function setUp() public override {
        // Call the base setup which handles diamond deployment
        super.setUp();
    }

    function testDeploymentBasics() public view {
        assertTrue(diamond != address(0), "Diamond should be deployed");
        address[] memory facets = IDiamondLoupe(diamond).facetAddresses();
        assertTrue(facets.length > 0, "Should have facets registered");
    }

    function testAdminRole() public view {
        assertTrue(AccessControlFacet(diamond).isAdmin(admin), "Admin should be set correctly");
    }
    
    function testManagementRole() public view {
        assertTrue(AccessControlFacet(diamond).isManager(admin), "Admin should have manager role");
    }
}
