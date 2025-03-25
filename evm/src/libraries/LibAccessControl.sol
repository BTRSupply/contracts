// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {BTRStorage as S} from "@libraries/BTRStorage.sol";
import {BTRErrors as Errors, BTREvents as Events} from "@libraries/BTREvents.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {AccessControl, RoleData, PendingAcceptance, ErrorType, TokenType, Rescue} from "@/BTRTypes.sol";
import {LibRescue} from "@libraries/LibRescue.sol";

/// @title LibAccessControl
/// @notice Library to manage role-based access control
library LibAccessControl {

    using EnumerableSet for EnumerableSet.AddressSet;

    /*═══════════════════════════════════════════════════════════════╗
    ║                          CONSTANTS                             ║
    ╚═══════════════════════════════════════════════════════════════*/

    uint256 public constant DEFAULT_GRANT_DELAY = 2 days;
    uint256 public constant DEFAULT_ACCEPT_WINDOW = 7 days;
    uint256 public constant MIN_GRANT_DELAY = 1 days;
    uint256 public constant MAX_GRANT_DELAY = 30 days;
    uint256 public constant MIN_ACCEPT_WINDOW = 1 days;
    uint256 public constant MAX_ACCEPT_WINDOW = 30 days;
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant TREASURY_ROLE = keccak256("TREASURY_ROLE");

    /*═══════════════════════════════════════════════════════════════╗
    ║                            VIEW                                ║
    ╚═══════════════════════════════════════════════════════════════*/

    function _getMember0(bytes32 role) internal view returns (address) {
        address[] memory members = getMembers(role);
        return members.length > 0 ? members[0] : address(0);
    }

    /// @notice Get the primary admin address
    /// @return The first admin in the list, or address(0) if none
    function admin() internal view returns (address) {
        return _getMember0(ADMIN_ROLE);
    }

    /// @notice Get the treasury address
    /// @return The first treasury in the list, or address(0) if none
    function treasury() internal view returns (address) {
        return _getMember0(TREASURY_ROLE);
    }

    /// @return Array of addresses with the manager role
    function getManagers() internal view returns (address[] memory) {
        return getMembers(MANAGER_ROLE);
    }
    
    /// @notice Get the keeper addresses
    /// @return Array of addresses with the keeper role
    function getKeepers() internal view returns (address[] memory) {
        return getMembers(KEEPER_ROLE);
    }

    /// @notice Check if an account is blacklisted
    /// @param account The account to check
    /// @return True if the account is blacklisted
    function isBlacklisted(address account) internal view returns (bool) {
        return S.accessControl().blacklist.contains(account);
    }
    
    /// @notice Check if an account has a role
    /// @param role The role to check
    /// @param account The account to check
    /// @return True if the account has the role
    function hasRole(bytes32 role, address account) internal view returns (bool) {
        AccessControl storage acs = S.accessControl();
        return _hasRole(acs, role, account);
    }

    /// @notice Verify that an account has a role, reverting if not
    /// @param role The role to check
    /// @param account The account to check
    function checkRole(bytes32 role, address account) internal view {
        if (!hasRole(role, account)) {
            revert Errors.Unauthorized(ErrorType.ACCESS);
        }
    }

    /// @notice Verify that the caller has a role
    /// @param role The role to check
    function checkRole(bytes32 role) internal view {
        checkRole(role, msg.sender);
    }

    /// @notice Check if an account has admin rights for a role
    /// @param role The role to check
    /// @param account The account to check
    function checkRoleAdmin(bytes32 role, address account) internal view {
        checkRole(getRoleAdmin(role), account);
    }

    /// @notice Check if the caller has admin rights for a role
    /// @param role The role to check
    function checkRoleAdmin(bytes32 role) internal view {
        checkRoleAdmin(role, msg.sender);
    }

    /// @notice Get the admin role for a role
    /// @param role The role to get the admin for
    /// @return The admin role
    function getRoleAdmin(bytes32 role) internal view returns (bytes32) {
        return S.accessControl().roles[role].adminRole;
    }

    /// @notice Get all members with a role
    /// @param role The role to get members for
    /// @return Array of addresses with the role
    function getMembers(bytes32 role) internal view returns (address[] memory) {
        AccessControl storage acs = S.accessControl();
        RoleData storage roleData = acs.roles[role];
        
        uint256 length = roleData.members.length();
        address[] memory result = new address[](length);
        
        for (uint256 i = 0; i < length;) {
            result[i] = roleData.members.at(i);
            unchecked { ++i; }
        }

        return result;
    }

    /// @notice Get the current timelock configuration
    /// @return grantDelay The delay before a role grant can be accepted
    /// @return acceptWindow The window of time during which a role grant can be accepted
    function getTimelockConfig() internal view returns (uint256 grantDelay, uint256 acceptWindow) {
        AccessControl storage acs = S.accessControl();
        return (acs.grantDelay, acs.acceptWindow);
    }

    /// @notice Validate a pending role acceptance
    /// @param acceptance The pending acceptance to check
    /// @param role The role being accepted
    function checkRoleAcceptance(
        PendingAcceptance memory acceptance,
        bytes32 role
    ) internal view {
        // Make sure the role accepted is the same as the pending one
        if (acceptance.role != role) {
            revert Errors.Unauthorized(ErrorType.ROLE);
        }
        
        // Grant the keeper role instantly (no attack surface here)
        if (acceptance.role == KEEPER_ROLE) return;
        
        (uint256 grantDelay, uint256 acceptWindow) = getTimelockConfig();
        
        // Check expiry
        if (block.timestamp > (acceptance.timestamp + grantDelay + acceptWindow)) {
            revert Errors.Expired(ErrorType.ACCEPTANCE);
        }
        
        // Check timelock
        if (block.timestamp < (acceptance.timestamp + grantDelay)) {
            revert Errors.Locked();
        }
    }

    /// @notice Get pending role acceptance for an account
    /// @param account The account to check
    /// @return The pending acceptance details
    function getPendingAcceptance(address account) internal view returns (PendingAcceptance memory) {
        return S.accessControl().pendingAcceptance[account];
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                      ROLE MODIFICATIONS                        ║
    ╚═══════════════════════════════════════════════════════════════*/

    /// @notice Set the admin role for a role
    /// @param role The role to set the admin for
    /// @param adminRole The new admin role
    function setRoleAdmin(bytes32 role, bytes32 adminRole) internal {
        if (role == ADMIN_ROLE) {
            revert Errors.Unauthorized(ErrorType.ADMIN); // 0x00 will always be the admin's admin role (top of the hierarchy)
        }

        RoleData storage roleData = S.accessControl().roles[role];
        
        bytes32 previousAdminRole = roleData.adminRole;
        roleData.adminRole = adminRole;
        
        emit Events.RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /// @notice Set the timelock configuration
    /// @param grantDelay The delay before a role grant can be accepted
    /// @param acceptWindow The window of time during which a role grant can be accepted
    function setTimelockConfig(uint256 grantDelay, uint256 acceptWindow) internal {
        if (grantDelay < MIN_GRANT_DELAY || grantDelay > MAX_GRANT_DELAY ||
            acceptWindow < MIN_ACCEPT_WINDOW || acceptWindow > MAX_ACCEPT_WINDOW) {
            revert Errors.OutOfRange(grantDelay, MIN_GRANT_DELAY, MAX_GRANT_DELAY);
        }
        
        AccessControl storage acs = S.accessControl();
        acs.grantDelay = grantDelay;
        acs.acceptWindow = acceptWindow;
        
        emit Events.TimelockConfigUpdated(grantDelay, acceptWindow);
    }

    /// @notice Create a pending role acceptance
    /// @param role The role to grant
    /// @param account The account to grant the role to
    /// @param sender The account granting the role
    function createRoleAcceptance(bytes32 role, address account, address sender) internal {
        if (account == address(0)) {
            revert Errors.ZeroAddress();
        }
        
        AccessControl storage acs = S.accessControl();
        
        if (_hasRole(acs, role, account)) {
            revert Errors.AlreadyExists(ErrorType.ROLE);
        }
        
        // Validate that the role exists (has an admin role defined)
        bytes32 adminRole = getRoleAdmin(role);
        if (adminRole == bytes32(0) && role != ADMIN_ROLE) {
            revert Errors.NotFound(ErrorType.ROLE);
        }

        // Prevent an account from replacing itself
        address replacing = role == ADMIN_ROLE ? sender : address(0);
        if (replacing == account) {
            revert Errors.InvalidParameter();
        }

        // No acceptance needed for keepers
        if (role == KEEPER_ROLE) {
            _grantRole(acs, role, account);
            return;
        }

        // Set up pending acceptance
        acs.pendingAcceptance[account] = PendingAcceptance({
            replacing: replacing,
            timestamp: uint64(block.timestamp),
            role: role
        });

        emit Events.RoleAcceptanceCreated(role, account, sender);
    }

    /// @notice Accept a pending role
    /// @param role The role to accept
    /// @param account The account accepting the role
    function acceptRole(bytes32 role, address account) internal {
        AccessControl storage acs = S.accessControl();
        PendingAcceptance memory acceptance = acs.pendingAcceptance[account];
        
        checkRoleAcceptance(acceptance, role);
        
        // Always grant the role first to ensure there's at least one admin
        _grantRole(acs, acceptance.role, account);
        
        address replacing = acceptance.replacing;
        if (replacing != address(0)) {
            // Clear all pending rescue requests if replacing an admin
            if (role == ADMIN_ROLE) {
                LibRescue.cancelRescueAll(replacing);
            }
            
            // Now revoke the role from the replaced account
            // This will work for admin too since we added the new admin first
            revokeRole(acceptance.role, replacing);
        }
        
        delete acs.pendingAcceptance[account];
    }

    /// @notice Cancel a pending role grant
    /// @param account The account with the pending role
    function cancelRoleGrant(address account) internal {
        AccessControl storage acs = S.accessControl();
        PendingAcceptance memory acceptance = acs.pendingAcceptance[account];
        
        // Only allow admin, role admin, or the account itself to cancel
        if (!_hasRole(acs, ADMIN_ROLE, msg.sender) && 
            !_hasRole(acs, getRoleAdmin(acceptance.role), msg.sender) &&
            msg.sender != account) {
            revert Errors.Unauthorized(ErrorType.ACCESS);
        }
        
        emit Events.RoleAcceptanceCreated(acceptance.role, address(0), account);
        delete acs.pendingAcceptance[account];
    }

    /// @notice Revoke a role from an account
    /// @param role The role to revoke
    /// @param account The account to revoke the role from
    function revokeRole(bytes32 role, address account) internal {
        AccessControl storage acs = S.accessControl();
        RoleData storage roleData = acs.roles[role];
        
        if (role == ADMIN_ROLE && roleData.members.length() == 1) {
            revert Errors.Unauthorized(ErrorType.ADMIN); // Cannot revoke the last admin
        }

        if (!_hasRole(acs, role, account)) {
            revert Errors.NotFound(ErrorType.ROLE);
        }

        roleData.members.remove(account);
        emit Events.RoleRevoked(role, account, msg.sender);
        
        // Emit ownership transferred event if this was an admin role
        if (role == ADMIN_ROLE) {
            // Find the first admin in the list to consider as the "owner"
            address newOwner = roleData.members.length() > 0 ? roleData.members.at(0) : address(0);
            emit Events.OwnershipTransferred(account, newOwner);
        }
    }

    /**
     * @notice Internal hasRole check that uses a storage pointer
     * @param acs AccessControl storage pointer
     * @param role The role to check
     * @param account The account to check
     */
    function _hasRole(AccessControl storage acs, bytes32 role, address account) private view returns (bool) {
        return acs.roles[role].members.contains(account);
    }

    /**
     * @notice Internal function to grant a role using storage pointer
     * @param acs AccessControl storage pointer
     * @param role The role to grant
     * @param account The account to grant the role to
     */
    function _grantRole(AccessControl storage acs, bytes32 role, address account) private {
        if (_hasRole(acs, role, account)) {
            return; // Account already has the role
        }
        
        RoleData storage roleData = acs.roles[role];
        roleData.members.add(account);
        
        emit Events.RoleGranted(role, account, msg.sender);
        
        // Emit ownership transfer event if this is an admin role
        if (role == ADMIN_ROLE) {
            emit Events.OwnershipTransferred(msg.sender, account);
        }
    }

    /// @notice Grants a role directly (bypassing acceptance flow)
    /// @param role The role to grant
    /// @param account The account to grant the role to
    function grantRole(bytes32 role, address account) internal {
        AccessControl storage acs = S.accessControl();
        _grantRole(acs, role, account);
    }

    /// @notice Create a pending role grant
    /// @param role The role to grant
    /// @param account The account to grant the role to
    /// @param replacing The account being replaced (if any)
    function grantPendingRole(bytes32 role, address account, address replacing) internal {
        AccessControl storage acs = S.accessControl();
        
        // If already has a pending acceptance for any role, revert
        if (acs.pendingAcceptance[account].role != bytes32(0)) {
            revert Errors.AlreadyExists(ErrorType.ROLE);
        }

        // Create pending acceptance
        PendingAcceptance storage acceptance = acs.pendingAcceptance[account];
        acceptance.role = role;
        acceptance.timestamp = uint64(block.timestamp);
        acceptance.replacing = replacing;

        // If replacing someone, check that they have the role
        if (replacing != address(0) && !_hasRole(acs, role, replacing)) {
            revert Errors.NotFound(ErrorType.ROLE);
        }

        emit Events.RoleAcceptanceCreated(role, account, msg.sender);
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                         INITIALIZATION                         ║
    ╚═══════════════════════════════════════════════════════════════*/

    /// @notice Initialize the access control system
    /// @param adminAddress The initial admin address
    function initialize(address adminAddress) internal {
        if (adminAddress == address(0)) {
            revert Errors.ZeroAddress();
        }

        // Check if already initialized
        if (admin() != address(0)) {
            revert Errors.AlreadyInitialized();
        }

        AccessControl storage acs = S.accessControl();
        
        // Grant initial roles
        _grantRole(acs, ADMIN_ROLE, adminAddress);
        _grantRole(acs, MANAGER_ROLE, adminAddress);

        // Set up role admins
        setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
        setRoleAdmin(MANAGER_ROLE, ADMIN_ROLE);
        setRoleAdmin(KEEPER_ROLE, ADMIN_ROLE);
        setRoleAdmin(TREASURY_ROLE, ADMIN_ROLE);

        // Set default timelock settings
        acs.grantDelay = DEFAULT_GRANT_DELAY;
        acs.acceptWindow = DEFAULT_ACCEPT_WINDOW;
        
        emit Events.TimelockConfigUpdated(DEFAULT_GRANT_DELAY, DEFAULT_ACCEPT_WINDOW);
    }
}
