// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibAccessControl as AC} from "../libraries/LibAccessControl.sol";
import {BTRStorage as S} from "../libraries/BTRStorage.sol";
import {BTRErrors as Errors, BTREvents as Events} from "../libraries/BTREvents.sol";
import {EnumerableSet} from "@openzeppelin/utils/structs/EnumerableSet.sol";
import {IERC173} from "../interfaces/IERC173.sol";
import {AccessControlStorage, PendingAcceptance, ErrorType} from "../BTRTypes.sol";
import {PermissionedFacet} from "./abstract/PermissionedFacet.sol";

/// @title AccessControlFacet
/// @notice Role-based access control facet for BTR contract
/// @dev Inspired by Astrolab's AccessController and OZ's AccessControlEnumerable
/// Also implements ERC173 for ownership backwards compatibility
contract AccessControlFacet is PermissionedFacet, IERC173 {
  using EnumerableSet for EnumerableSet.AddressSet;
  using AC for bytes32;

  /*═══════════════════════════════════════════════════════════════╗
  ║                      ERC-173 COMPLIANCE                        ║
  ╚═══════════════════════════════════════════════════════════════*/

  /// @notice Returns the address of the owner (ERC-173)
  /// @return owner_ of the contract (the admin role holder)
  function owner() external view override returns (address owner_) {
    return AC.admin();
  }

  /// @notice Transfers ownership of the contract to a new address (ERC-173)
  /// @param _newOwner The address to transfer ownership to
  function transferOwnership(address _newOwner) external override onlyAdmin {
    // Require non-zero address
    if (_newOwner == address(0)) {
        revert Errors.ZeroAddress();
    }
    
    // Set up pending acceptance for admin role (this is the primary ownership mechanism)
    AC.ADMIN_ROLE.createRoleAcceptance(_newOwner, msg.sender);

    // Emit ownership transfer event
    emit Events.OwnershipTransferred(msg.sender, _newOwner);
  }

  /*═══════════════════════════════════════════════════════════════╗
  ║                             VIEWS                              ║
  ╚═══════════════════════════════════════════════════════════════*/

  /// @notice Gets the admin role for a specific role
  /// @param role The role to get the admin for
  /// @return bytes32 The admin role
  function getRoleAdmin(bytes32 role) public view returns (bytes32) {
    return role.getRoleAdmin();
  }

  /// @notice Gets all members of a role
  /// @param role The role to get members for
  /// @return Array of addresses with the role
  function getMembers(bytes32 role) public view returns (address[] memory) {
    return role.getMembers();
  }

  /// @notice Get current grant delay and accept window
  /// @return grantDelay Current grant delay
  /// @return acceptWindow Current accept window
  function getTimelockConfig() external view returns (uint256 grantDelay, uint256 acceptWindow) {
    AccessControlStorage storage acs = S.accessControl();
    return (acs.grantDelay, acs.acceptWindow);
  }

  /// @notice Checks acceptance state for a pending role change
  /// @param acceptance The acceptance data to check
  /// @param role The role to check against
  function checkRoleAcceptance(
    PendingAcceptance memory acceptance,
    bytes32 role
  ) public view {
    // Make sure the role accepted is the same as the pending one
    if (acceptance.role != role) {
      revert Errors.Unauthorized(ErrorType.ROLE);
    }
    
    // Grant the keeper role instantly (no attack surface here)
    if (acceptance.role == AC.KEEPER_ROLE) return;
    
    (uint256 grantDelay, uint256 acceptWindow) = AC.getTimelockConfig();
    
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

  /// @notice Returns the pending role details for an account
  /// @param role The role to check
  /// @param account The account to check
  /// @return pendingRole The pending role
  /// @return replacing The address being replaced (for ADMIN)
  /// @return timestamp When the role grant was initiated
  function getPendingAcceptance(bytes32 role, address account) 
    external 
    view 
    returns (
      bytes32 pendingRole,
      address replacing,
      uint64 timestamp
    )
  {
    PendingAcceptance memory acceptance = AC.getPendingAcceptance(account);
    
    return (
      acceptance.role,
      acceptance.replacing,
      acceptance.timestamp
    );
  }

  /// @return Address of the admin
  function admin() external view returns (address) {
    return AC.admin();
  }

  /// @return Array of MANAGER addresses
  function getManagers() external view returns (address[] memory) {
    return AC.MANAGER_ROLE.getMembers();
  }

  /// @return Array of KEEPER addresses
  function getKeepers() external view returns (address[] memory) {
    return AC.KEEPER_ROLE.getMembers();
  }

  /*═══════════════════════════════════════════════════════════════╗
  ║                          INITIALIZE                            ║
  ╚═══════════════════════════════════════════════════════════════*/

  /// @notice Initialize the access control with default roles
  /// @param initialAdmin The initial admin address
  function initialize(address initialAdmin) external {
    AC.initialize(initialAdmin);
  }

  /*═══════════════════════════════════════════════════════════════╗
  ║                             LOGIC                              ║
  ╚═══════════════════════════════════════════════════════════════*/

  /// @notice Sets admin role for a specific role
  /// @param role The role to set the admin for
  /// @param adminRole The admin role to set
  function setRoleAdmin(bytes32 role, bytes32 adminRole) external onlyAdmin {
    AC.setRoleAdmin(role, adminRole);
  }

  /// @notice Update timelock configuration
  /// @param grantDelay New grant delay (in seconds)
  /// @param acceptWindow New accept window (in seconds)
  function setTimelockConfig(uint256 grantDelay, uint256 acceptWindow) external onlyAdmin {
    if (grantDelay < AC.MIN_GRANT_DELAY || grantDelay > AC.MAX_GRANT_DELAY ||
        acceptWindow < AC.MIN_ACCEPT_WINDOW || acceptWindow > AC.MAX_ACCEPT_WINDOW) {
        revert Errors.OutOfRange(grantDelay, AC.MIN_GRANT_DELAY, AC.MAX_GRANT_DELAY);
    }
    AC.setTimelockConfig(grantDelay, acceptWindow);
  }

  /// @notice Grants role to account
  /// @param role The role to grant
  /// @param account The account to grant the role to
  function grantRole(
    bytes32 role,
    address account
  ) external onlyRoleAdmin(role) {
    if (AC.hasRole(role, account)) {
      revert Errors.AlreadyExists(ErrorType.ROLE);
    }
    AC.createRoleAcceptance(role, account, msg.sender);
  }

  /// @notice Revokes role from account
  /// @param role The role to revoke
  /// @param account The account to revoke from
  function revokeRole(
    bytes32 role,
    address account
  ) external onlyRoleAdmin(role) {
    AC.revokeRole(role, account);
  }

  /// @notice Renounces a role (self-revocation)
  /// @param role The role to renounce
  function renounceRole(bytes32 role) external {
    AC.revokeRole(role, msg.sender);
  }

  /// @notice Accepts a pending role grant
  /// @param role The role to accept
  function acceptRole(bytes32 role) external {
    AC.processRoleAcceptance(role, msg.sender);
  }

  /// @notice Cancel a pending role grant
  /// @param account The account to cancel for
  function cancelRoleGrant(address account) external {
    AC.cancelRoleAcceptance(account);
  }
}
