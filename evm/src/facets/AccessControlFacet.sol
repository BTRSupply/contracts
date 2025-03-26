// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC173} from "@interfaces/ercs/IERC173.sol";
import {AccessControl, PendingAcceptance, ErrorType} from "@/BTRTypes.sol";
import {BTRErrors as Errors} from "@libraries/BTREvents.sol";
import {LibAccessControl as AC} from "@libraries/LibAccessControl.sol";
import {PermissionedFacet} from "@facets/abstract/PermissionedFacet.sol";
import {NonReentrantFacet} from "@facets/abstract/NonReentrantFacet.sol";

/**
 * @title AccessControlFacet
 * @notice Diamond facet for role-based access control
 */
contract AccessControlFacet is PermissionedFacet, NonReentrantFacet, IERC173 {

    /*═══════════════════════════════════════════════════════════════╗
    ║                      ERC-173 COMPLIANCE                        ║
    ╚═══════════════════════════════════════════════════════════════*/

    /// @inheritdoc IERC173
    function owner() external view override returns (address) {
        return AC.admin();
    }

    /// @inheritdoc IERC173
    function transferOwnership(address _newOwner) external override onlyAdmin {
        if (_newOwner == address(0)) revert Errors.ZeroAddress();
        AC.createRoleAcceptance(AC.ADMIN_ROLE, _newOwner, msg.sender);
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                             VIEWS                              ║
    ╚═══════════════════════════════════════════════════════════════*/

    /// @notice Get all addresses with the specified role
    function getMembers(bytes32 role) external view returns (address[] memory) {
        return AC.getMembers(role);
    }

    /// @notice Get current timelock configuration
    function getTimelockConfig() external view returns (uint256 grantDelay, uint256 acceptWindow) {
        return AC.getTimelockConfig();
    }

    /// @notice Validate a pending role acceptance
    function checkRoleAcceptance(PendingAcceptance calldata acceptance, bytes32 role) external view {
        AC.checkRoleAcceptance(acceptance, role);
    }

    /// @notice Get pending role acceptance details for an account
    function getPendingAcceptance(address account) external view returns (bytes32 pendingRole, address replacing, uint64 timestamp) {
        PendingAcceptance memory acceptance = AC.getPendingAcceptance(account);
        return (acceptance.role, acceptance.replacing, acceptance.timestamp);
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                      STATE CHANGING FUNCTIONS                  ║
    ╚═══════════════════════════════════════════════════════════════*/

    /// @notice Initialize access control with the first admin
    function initializeAccessControl(address initialAdmin) external {
        AC.initialize(initialAdmin);
    }

    /// @notice Set the admin role for a role
    function setRoleAdmin(bytes32 role, bytes32 adminRole) external onlyAdmin {
        AC.setRoleAdmin(role, adminRole);
    }

    /// @notice Set timelock configuration for role grants
    function setTimelockConfig(uint256 grantDelay, uint256 acceptWindow) external onlyAdmin {
        AC.setTimelockConfig(grantDelay, acceptWindow);
    }

    /// @notice Grant a role to an account (creates a pending acceptance)
    function grantRole(bytes32 role, address account) external onlyRoleAdmin(role) {
        AC.createRoleAcceptance(role, account, msg.sender);
    }

    /// @notice Revoke a role from an account
    function revokeRole(bytes32 role, address account) external onlyRoleAdmin(role) {
        AC.revokeRole(role, account);
    }

    /// @notice Renounce a role (sender gives up their own role)
    function renounceRole(bytes32 role) external {
        AC.revokeRole(role, msg.sender);
    }

    /// @notice Accept a pending role grant
    function acceptRole(bytes32 role) external nonReentrant {
        AC.acceptRole(role, msg.sender);
    }

    /// @notice Cancel a pending role grant
    function cancelRoleGrant(address account) external {
        AC.cancelRoleGrant(account);
    }
}
