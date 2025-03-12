// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {BTRStorage as S} from "./BTRStorage.sol";
import {BTRErrors as Errors, BTREvents as Events} from "./BTREvents.sol";
import {EnumerableSet} from "@openzeppelin/utils/structs/EnumerableSet.sol";
import {AccessControlStorage, RoleData, PendingAcceptance, ErrorType, TokenType, RescueStorage} from "../BTRTypes.sol";
import {LibRescue} from "./LibRescue.sol";

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

    function admin() internal view returns (address) {
        address[] memory admins = getMembers(ADMIN_ROLE);
        return admins.length > 0 ? admins[0] : address(0);
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                       ROLE MANAGEMENT                          ║
    ╚═══════════════════════════════════════════════════════════════*/
    
    function accessControlStorage() internal pure returns (AccessControlStorage storage) {
        return S.accessControl();
    }

    function hasRole(bytes32 role, address account) internal view returns (bool) {
        return S.accessControl().roles[role].members.contains(account);
    }

    function checkRole(bytes32 role, address account) internal view {
        if (!hasRole(role, account)) {
            revert Errors.Unauthorized(ErrorType.ACCESS);
        }
    }

    function checkRole(bytes32 role) internal view {
        checkRole(role, msg.sender);
    }

    function checkRoleAdmin(bytes32 role, address account) internal view {
        checkRole(getRoleAdmin(role), account);
    }

    function checkRoleAdmin(bytes32 role) internal view {
        checkRoleAdmin(role, msg.sender);
    }

    function getRoleAdmin(bytes32 role) internal view returns (bytes32) {
        return S.accessControl().roles[role].adminRole;
    }

    function getMembers(bytes32 role) internal view returns (address[] memory) {
        AccessControlStorage storage acs = S.accessControl();
        RoleData storage roleData = acs.roles[role];
        
        uint256 length = roleData.members.length();
        address[] memory result = new address[](length);
        
        for (uint256 i = 0; i < length; i++) {
            result[i] = roleData.members.at(i);
        }

        return result;
    }

    function getTimelockConfig() internal view returns (uint256 grantDelay, uint256 acceptWindow) {
        AccessControlStorage storage acs = S.accessControl();
        return (acs.grantDelay, acs.acceptWindow);
    }

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
        if (
            block.timestamp > (acceptance.timestamp + grantDelay + acceptWindow)
        ) {
            revert Errors.Expired(ErrorType.ACCEPTANCE);
        }
        
        // Check timelock
        if (block.timestamp < (acceptance.timestamp + grantDelay)) {
            revert Errors.Locked();
        }
    }

    function getPendingAcceptance(address account) internal view returns (PendingAcceptance memory) {
        return S.accessControl().pendingAcceptance[account];
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                      ROLE MODIFICATIONS                        ║
    ╚═══════════════════════════════════════════════════════════════*/

    function setRoleAdmin(bytes32 role, bytes32 adminRole) internal {
        if (role == ADMIN_ROLE) {
            revert Errors.Unauthorized(ErrorType.ADMIN); // 0x00 will always be the admin's admin role (top of the hierarchy)
        }

        AccessControlStorage storage acs = S.accessControl();
        RoleData storage roleData = acs.roles[role];
        
        bytes32 previousAdminRole = roleData.adminRole;
        roleData.adminRole = adminRole;
        
        emit Events.RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    function setTimelockConfig(uint256 grantDelay, uint256 acceptWindow) internal {
        if (grantDelay < MIN_GRANT_DELAY || grantDelay > MAX_GRANT_DELAY ||
            acceptWindow < MIN_ACCEPT_WINDOW || acceptWindow > MAX_ACCEPT_WINDOW) {
            revert Errors.OutOfRange(grantDelay, MIN_GRANT_DELAY, MAX_GRANT_DELAY);
        }
        
        AccessControlStorage storage acs = S.accessControl();
        acs.grantDelay = grantDelay;
        acs.acceptWindow = acceptWindow;
        
        emit Events.TimelockConfigUpdated(grantDelay, acceptWindow);
    }

    function createRoleAcceptance(bytes32 role, address account, address sender) internal {
        if (account == address(0)) {
            revert Errors.ZeroAddress();
        }
        
        if (hasRole(role, account)) {
            revert Errors.AlreadyExists(ErrorType.ROLE);
        }

        // No acceptance needed for keepers
        if (role == KEEPER_ROLE) {
            grantRole(role, account);
            return;
        }

        // Set up pending acceptance
        AccessControlStorage storage acs = S.accessControl();
        acs.pendingAcceptance[account] = PendingAcceptance({
            // Only get replaced if admin (managers can coexist)
            replacing: role == ADMIN_ROLE ? sender : address(0),
            timestamp: uint64(block.timestamp),
            role: role
        });

        emit Events.RoleAcceptanceCreated(role, account, sender);
    }

    function processRoleAcceptance(bytes32 role, address account) internal {
        AccessControlStorage storage acs = S.accessControl();
        PendingAcceptance memory acceptance = acs.pendingAcceptance[account];
        
        checkRoleAcceptance(acceptance, role);
        
        if (acceptance.replacing != address(0)) {
            // If replacing, revoke the old role
            revokeRole(acceptance.role, acceptance.replacing);
            
            // If this is an admin role transfer, clear all pending rescue requests
            if (role == ADMIN_ROLE) {
                LibRescue.cancelRescueAll(acceptance.replacing);
            }
        }

        grantRole(acceptance.role, account);
        delete acs.pendingAcceptance[account];
    }

    function cancelRoleAcceptance(address account) internal {
        AccessControlStorage storage acs = S.accessControl();
        PendingAcceptance memory acceptance = acs.pendingAcceptance[account];
        
        // Only allow admin, role admin, or the account itself to cancel
        if (!hasRole(ADMIN_ROLE, msg.sender) && 
            !hasRole(getRoleAdmin(acceptance.role), msg.sender) &&
            msg.sender != account) {
            revert Errors.Unauthorized(ErrorType.ACCESS);
        }
        
        emit Events.RoleAcceptanceCreated(acceptance.role, address(0), account);
        delete acs.pendingAcceptance[account];
    }

    function grantRole(bytes32 role, address account) internal {
        AccessControlStorage storage acs = S.accessControl();
        RoleData storage roleData = acs.roles[role];
        
        if (roleData.members.contains(account)) {
            revert Errors.AlreadyExists(ErrorType.ROLE);
        }
        
        roleData.members.add(account);
        emit Events.RoleGranted(role, account, msg.sender);
        if (role == ADMIN_ROLE) {
            emit Events.OwnershipTransferred(msg.sender, account);
        }
    }

    function revokeRole(bytes32 role, address account) internal {
        if (role == ADMIN_ROLE) {
            revert Errors.Unauthorized(ErrorType.ADMIN); // Admin role can't be revoked as it would brick the contract
        }
        
        if (!hasRole(role, account)) {
            revert Errors.NotFound(ErrorType.ROLE);
        }

        AccessControlStorage storage acs = S.accessControl();
        RoleData storage roleData = acs.roles[role];
        
        roleData.members.remove(account);
        emit Events.RoleRevoked(role, account, msg.sender);
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                         INITIALIZATION                         ║
    ╚═══════════════════════════════════════════════════════════════*/

    function initialize(address adminAddress) internal {
        if (adminAddress == address(0)) {
            revert Errors.ZeroAddress();
        }

        // Check if already initialized
        if (admin() != address(0)) {
            revert Errors.AlreadyInitialized();
        }

        // Grant initial roles
        grantRole(ADMIN_ROLE, adminAddress);
        grantRole(MANAGER_ROLE, adminAddress);

        // Set up role admins
        setRoleAdmin(KEEPER_ROLE, ADMIN_ROLE);
        setRoleAdmin(MANAGER_ROLE, ADMIN_ROLE);
        setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
        setRoleAdmin(TREASURY_ROLE, ADMIN_ROLE);

        // Set default timelock settings
        AccessControlStorage storage acs = S.accessControl();
        acs.grantDelay = DEFAULT_GRANT_DELAY;
        acs.acceptWindow = DEFAULT_ACCEPT_WINDOW;
        
        emit Events.TimelockConfigUpdated(DEFAULT_GRANT_DELAY, DEFAULT_ACCEPT_WINDOW);
    }
}
