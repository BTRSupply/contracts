// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {DiamondDeployer} from "@utils/DiamondDeployer.sol";
import {AccessControlFacet} from "@facets/AccessControlFacet.sol";
import {LibAccessControl} from "@libraries/LibAccessControl.sol";

contract AccessControlTest is Test {
    DiamondDeployer.Deployment deployment;
    address admin;
    address manager;
    address keeper;

    function setUp() public {
        admin = address(this);
        manager = address(0x1);
        keeper = address(0x2);

        DiamondDeployer diamondDeployer = new DiamondDeployer();
        deployment = diamondDeployer.deployDiamond(admin);
    }

    function testRoleHierarchy() public {
        AccessControlFacet ac = AccessControlFacet(address(deployment.diamond));
        
        // Admin should have admin role
        assertTrue(ac.hasRole(LibAccessControl.ADMIN_ROLE, admin));
        
        // Grant manager role
        ac.grantRole(LibAccessControl.MANAGER_ROLE, manager);
        assertTrue(ac.hasRole(LibAccessControl.MANAGER_ROLE, manager));
        
        // Grant keeper role
        ac.grantRole(LibAccessControl.KEEPER_ROLE, keeper);
        assertTrue(ac.hasRole(LibAccessControl.KEEPER_ROLE, keeper));
        
        // Verify role hierarchy
        assertTrue(ac.isAdmin(admin));
        assertTrue(ac.isManager(manager));
        assertTrue(ac.isKeeper(keeper));
        
        // Manager should not have admin privileges
        assertFalse(ac.isAdmin(manager));
        
        // Keeper should not have manager privileges
        assertFalse(ac.isManager(keeper));
    }

    function testRoleRevocation() public {
        AccessControlFacet ac = AccessControlFacet(address(deployment.diamond));
        
        // Setup roles
        ac.grantRole(LibAccessControl.MANAGER_ROLE, manager);
        ac.grantRole(LibAccessControl.KEEPER_ROLE, keeper);
        
        // Revoke keeper role
        ac.revokeRole(LibAccessControl.KEEPER_ROLE, keeper);
        assertFalse(ac.hasRole(LibAccessControl.KEEPER_ROLE, keeper));
        
        // Revoke manager role
        ac.revokeRole(LibAccessControl.MANAGER_ROLE, manager);
        assertFalse(ac.hasRole(LibAccessControl.MANAGER_ROLE, manager));
    }

    function testRoleRenunciation() public {
        AccessControlFacet ac = AccessControlFacet(address(deployment.diamond));
        
        // Setup roles
        ac.grantRole(LibAccessControl.MANAGER_ROLE, manager);
        ac.grantRole(LibAccessControl.KEEPER_ROLE, keeper);
        
        // Keeper renounces role
        vm.prank(keeper);
        ac.renounceRole(LibAccessControl.KEEPER_ROLE);
        assertFalse(ac.hasRole(LibAccessControl.KEEPER_ROLE, keeper));
        
        // Manager renounces role
        vm.prank(manager);
        ac.renounceRole(LibAccessControl.MANAGER_ROLE);
        assertFalse(ac.hasRole(LibAccessControl.MANAGER_ROLE, manager));
    }
} 