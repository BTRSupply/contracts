// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {LibAccessControl as AC} from "@libraries/LibAccessControl.sol";

abstract contract PermissionedFacet {

    modifier onlyRole(bytes32 role) virtual {
        AC.checkRole(role);
        _;
    }

    modifier onlyRoleAdmin(bytes32 role) virtual {
        AC.checkRoleAdmin(role);
        _;
    }

    modifier onlyAdmin() virtual {
        AC.checkRole(AC.ADMIN_ROLE);
        _;
    }

    modifier onlyManager() virtual {
        AC.checkRole(AC.MANAGER_ROLE);
        _;
    }

    modifier onlyKeeper() virtual {
        AC.checkRole(AC.KEEPER_ROLE);
        _;
    }

    modifier onlyTreasury() virtual {
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
    
    function admin() external view virtual returns (address) {
        return AC.admin();
    }

    function treasury() external view virtual returns (address) {
        return AC.treasury();
    }

    function getManagers() external view virtual returns (address[] memory) {
        return AC.getMembers(AC.MANAGER_ROLE);
    }

    function getKeepers() external view virtual returns (address[] memory) {
        return AC.getMembers(AC.KEEPER_ROLE);
    }
    
    function isBlacklisted(address account) external view virtual returns (bool) {
        return AC.isBlacklisted(account);
    }

    function isWhitelisted(address account) external view virtual returns (bool) {
        return AC.isWhitelisted(account);
    }
}
