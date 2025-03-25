// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC173} from "@interfaces/ercs/IERC173.sol";
import {IPermissioned} from "@interfaces/IPermissioned.sol";
import {PendingAcceptance} from "@/BTRTypes.sol";

/**
 * @title IAccessControl
 * @notice Diamond facet interface for role-based access control
 */
interface IAccessControl is IPermissioned, IERC173 {
    
    function getMembers(bytes32 role) external view returns (address[] memory);
    function getTimelockConfig() external view returns (uint256 grantDelay, uint256 acceptWindow);
    function checkRoleAcceptance(PendingAcceptance calldata acceptance, bytes32 role) external view;
    function getPendingAcceptance(address account) external view returns (bytes32 pendingRole, address replacing, uint64 timestamp);
    function admin() external view returns (address);
    function getManagers() external view returns (address[] memory);
    function getKeepers() external view returns (address[] memory);

    function initializeAccessControl(address initialAdmin) external;
    function setRoleAdmin(bytes32 role, bytes32 adminRole) external;
    function setTimelockConfig(uint256 grantDelay, uint256 acceptWindow) external;
    function grantRole(bytes32 role, address account) external;
    function revokeRole(bytes32 role, address account) external;
    function renounceRole(bytes32 role) external;
    function acceptRole(bytes32 role) external;
    function cancelRoleGrant(address account) external;
}
