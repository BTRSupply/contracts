// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {LibAccessControl as AC} from "../../libraries/LibAccessControl.sol";

/// @title PermissionedFacet
/// @notice Abstract contract that provides role-based access control modifiers
abstract contract PermissionedFacet {

    modifier onlyRole(bytes32 role) {
        AC.checkRole(role);
        _;
    }

    modifier onlyRoleAdmin(bytes32 role) {
        AC.checkRoleAdmin(role);
        _;
    }

    modifier onlyAdmin() {
        AC.checkRole(AC.ADMIN_ROLE);
        _;
    }

    modifier onlyManager() {
        AC.checkRole(AC.MANAGER_ROLE);
        _;
    }

    modifier onlyKeeper() {
        AC.checkRole(AC.KEEPER_ROLE);
        _;
    }

    modifier onlyTreasury() {
        AC.checkRole(AC.TREASURY_ROLE);
        _;
    }

    function hasRole(bytes32 role, address account) public view returns (bool) {
        return AC.hasRole(role, account);
    }

    function checkRole(bytes32 role) public view {
        AC.checkRole(role);
    }

    function checkRole(bytes32 role, address account) public view {
        AC.checkRole(role, account);
    }

    function isAdmin(address account) external view returns (bool) {
        return hasRole(AC.ADMIN_ROLE, account);
    }

    function isManager(address account) external view returns (bool) {
        return hasRole(AC.MANAGER_ROLE, account);
    }

    function isKeeper(address account) external view returns (bool) {
        return hasRole(AC.KEEPER_ROLE, account);
    }

    function isTreasury(address account) external view returns (bool) {
        return hasRole(AC.TREASURY_ROLE, account);
    }
}
