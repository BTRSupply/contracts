// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@interfaces/IPermissionedFacet.sol";

/**
 * @title MockDiamond
 * @notice Mock implementation of the Diamond contract for testing BTR token
 * @dev Implements IPermissionedFacet for role-based access control testing
 */
contract MockDiamond is IPermissionedFacet {
    // Role constants
    bytes32 private constant _ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 private constant _MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 private constant _KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 private constant _TREASURY_ROLE = keccak256("TREASURY_ROLE");

    // Maps role => account => hasRole
    mapping(bytes32 => mapping(address => bool)) private _roles;
    // Maps account => isBlacklisted
    mapping(address => bool) private _blacklist;
    // Role members
    mapping(bytes32 => address[]) private _roleMembers;
    
    // Admin address
    address private _admin;
    // Treasury address
    address private _treasury;
    
    constructor(address admin) {
        require(admin != address(0), "Admin cannot be zero address");
        _admin = admin;
        _roles[_ADMIN_ROLE][admin] = true;
        _roleMembers[_ADMIN_ROLE].push(admin);
    }
    
    // Set treasury address
    function setTreasury(address treasury) external {
        require(treasury != address(0), "Treasury cannot be zero address");
        _treasury = treasury;
        _roles[_TREASURY_ROLE][treasury] = true;
        _roleMembers[_TREASURY_ROLE].push(treasury);
    }
    
    // Add an address to the blacklist
    function addToBlacklist(address account) external {
        _blacklist[account] = true;
    }
    
    // Remove an address from the blacklist
    function removeFromBlacklist(address account) external {
        _blacklist[account] = false;
    }
    
    // Grant a role to an account
    function grantRole(bytes32 role, address account) external {
        require(account != address(0), "Account cannot be zero address");
        _roles[role][account] = true;
        
        // Add to role members if not already there
        bool found = false;
        for (uint i = 0; i < _roleMembers[role].length; i++) {
            if (_roleMembers[role][i] == account) {
                found = true;
                break;
            }
        }
        if (!found) {
            _roleMembers[role].push(account);
        }
    }
    
    // Revoke a role from an account
    function revokeRole(bytes32 role, address account) external {
        _roles[role][account] = false;
        
        // Remove from role members
        for (uint i = 0; i < _roleMembers[role].length; i++) {
            if (_roleMembers[role][i] == account) {
                _roleMembers[role][i] = _roleMembers[role][_roleMembers[role].length - 1];
                _roleMembers[role].pop();
                break;
            }
        }
    }
    
    // IPermissionedFacet implementation
    
    function ADMIN_ROLE() external pure override returns (bytes32) {
        return _ADMIN_ROLE;
    }
    
    function MANAGER_ROLE() external pure override returns (bytes32) {
        return _MANAGER_ROLE;
    }
    
    function KEEPER_ROLE() external pure override returns (bytes32) {
        return _KEEPER_ROLE;
    }
    
    function TREASURY_ROLE() external pure override returns (bytes32) {
        return _TREASURY_ROLE;
    }
    
    function hasRole(bytes32 role, address account) external view override returns (bool) {
        return _roles[role][account];
    }
    
    function checkRole(bytes32 role) external view override {
        require(_roles[role][msg.sender], "Caller does not have the required role");
    }
    
    function checkRole(bytes32 role, address account) external view override {
        require(_roles[role][account], "Account does not have the required role");
    }
    
    function isAdmin(address account) external view override returns (bool) {
        return _roles[_ADMIN_ROLE][account];
    }
    
    function isManager(address account) external view override returns (bool) {
        return _roles[_MANAGER_ROLE][account];
    }
    
    function isKeeper(address account) external view override returns (bool) {
        return _roles[_KEEPER_ROLE][account];
    }
    
    function isTreasury(address account) external view override returns (bool) {
        return _roles[_TREASURY_ROLE][account];
    }
    
    function isBlacklisted(address account) external view override returns (bool) {
        return _blacklist[account];
    }
    
    function admin() external view override returns (address) {
        return _admin;
    }
    
    function treasury() external view override returns (address) {
        return _treasury;
    }
    
    function getManagers() external view override returns (address[] memory) {
        return _roleMembers[_MANAGER_ROLE];
    }
    
    function getKeepers() external view override returns (address[] memory) {
        return _roleMembers[_KEEPER_ROLE];
    }
    
    function getTreasuryAddresses() external view override returns (address[] memory) {
        return _roleMembers[_TREASURY_ROLE];
    }
} 