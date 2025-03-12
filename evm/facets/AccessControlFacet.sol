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

contract AccessControlFacet is PermissionedFacet, IERC173 {
  using EnumerableSet for EnumerableSet.AddressSet;

  /*═══════════════════════════════════════════════════════════════╗
  ║                      ERC-173 COMPLIANCE                        ║
  ╚═══════════════════════════════════════════════════════════════*/

  function owner() external view override returns (address owner_) {
    return AC.admin();
  }

  function transferOwnership(address _newOwner) external override onlyAdmin {
    // Require non-zero address
    if (_newOwner == address(0)) {
        revert Errors.ZeroAddress();
    }
    
    // Set up pending acceptance for admin role (this is the primary ownership mechanism)
    AC.createRoleAcceptance(AC.ADMIN_ROLE, _newOwner, msg.sender);

    // Emit ownership transfer event
    emit Events.OwnershipTransferred(msg.sender, _newOwner);
  }

  /*═══════════════════════════════════════════════════════════════╗
  ║                             VIEWS                              ║
  ╚═══════════════════════════════════════════════════════════════*/

  function getRoleAdmin(bytes32 role) public view returns (bytes32) {
    return AC.getRoleAdmin(role);
  }

  function getMembers(bytes32 role) public view returns (address[] memory) {
    return AC.getMembers(role);
  }

  function getTimelockConfig() external view returns (uint256 grantDelay, uint256 acceptWindow) {
    return AC.getTimelockConfig();
  }

  function checkRoleAcceptance(
    PendingAcceptance memory acceptance,
    bytes32 role
  ) public view {
    AC.checkRoleAcceptance(acceptance, role);
  }

  function getPendingAcceptance(address account) 
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

  function admin() external view returns (address) {
    return AC.admin();
  }

  function getManagers() external view returns (address[] memory) {
    return AC.getMembers(AC.MANAGER_ROLE);
  }

  function getKeepers() external view returns (address[] memory) {
    return AC.getMembers(AC.KEEPER_ROLE);
  }

  /*═══════════════════════════════════════════════════════════════╗
  ║                          INITIALIZE                            ║
  ╚═══════════════════════════════════════════════════════════════*/

  function initialize(address initialAdmin) external {
    AC.initialize(initialAdmin);
  }

  /*═══════════════════════════════════════════════════════════════╗
  ║                             LOGIC                              ║
  ╚═══════════════════════════════════════════════════════════════*/

  function setRoleAdmin(bytes32 role, bytes32 adminRole) external onlyAdmin {
    AC.setRoleAdmin(role, adminRole);
  }

  function setTimelockConfig(uint256 grantDelay, uint256 acceptWindow) external onlyAdmin {
    AC.setTimelockConfig(grantDelay, acceptWindow);
  }

  function grantRole(
    bytes32 role,
    address account
  ) external onlyRoleAdmin(role) {
    AC.createRoleAcceptance(role, account, msg.sender);
  }

  function revokeRole(
    bytes32 role,
    address account
  ) external onlyRoleAdmin(role) {
    AC.revokeRole(role, account);
  }

  function renounceRole(bytes32 role) external {
    AC.revokeRole(role, msg.sender);
  }

  function acceptRole(bytes32 role) external {
    AC.processRoleAcceptance(role, msg.sender);
  }

  function cancelRoleGrant(address account) external {
    AC.cancelRoleAcceptance(account);
  }
}
