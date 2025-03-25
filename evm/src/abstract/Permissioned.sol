// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IPermissioned} from "@interfaces/IPermissioned.sol";

/// @title Permissioned
/// @notice Abstract contract for external contracts to validate roles via the Diamond
abstract contract Permissioned {
    /// @dev The diamond contract address that handles role validation
    address public immutable diamond;
    
    /// @notice Constructor to set the diamond address
    /// @param _diamond Address of the diamond contract for role validation
    constructor(address _diamond) {
        require(_diamond != address(0), "Permissioned: zero address");
        diamond = _diamond;
    }

    /// @dev Access to permission checking functions via interface
    function permissioned() internal view returns (IPermissioned) {
        return IPermissioned(diamond);
    }

    /// @notice Modifier to check if the caller has a specific role
    /// @param role The role to validate
    modifier onlyRole(bytes32 role) virtual {
        permissioned().checkRole(role, msg.sender);
        _;
    }
    
    /// @notice Modifier for admin-only functions
    modifier onlyAdmin() virtual {
        permissioned().isAdmin(msg.sender);
        _;
    }
    
    /// @notice Modifier for manager-only functions
    modifier onlyManager() virtual {
        permissioned().isManager(msg.sender);
        _;
    }
    
    /// @notice Modifier for keeper-only functions
    modifier onlyKeeper() virtual {
        permissioned().isKeeper(msg.sender);
        _;
    }
    
    /// @notice Modifier for treasury-only functions
    modifier onlyTreasury() virtual {
        permissioned().isTreasury(msg.sender);
        _;
    }

    /// @notice Check if an account has a specific role
    /// @param role The role to check
    /// @param account The account to validate
    /// @return True if the account has the specified role
    function hasRole(bytes32 role, address account) public view virtual returns (bool) {
        return permissioned().hasRole(role, account);
    }
    
    /// @notice Verify that an account has a specific role, reverting if not
    /// @param role The role to check
    /// @param account The account to validate
    function checkRole(bytes32 role, address account) public view virtual {
        permissioned().checkRole(role, account);
    }
    
    /// @notice Verify that the caller has a specific role
    /// @param role The role to check
    function checkRole(bytes32 role) public view virtual {
        permissioned().checkRole(role, msg.sender);
    }
    
    /// @notice Check if an account is an admin
    /// @param account The account to check
    /// @return True if the account has the admin role
    function isAdmin(address account) external view virtual returns (bool) {
        return permissioned().isAdmin(account);
    }
    
    /// @notice Check if an account is a manager
    /// @param account The account to check
    /// @return True if the account has the manager role
    function isManager(address account) external view virtual returns (bool) {
        return permissioned().isManager(account);
    }
    
    /// @notice Check if an account is a keeper
    /// @param account The account to check
    /// @return True if the account has the keeper role
    function isKeeper(address account) external view virtual returns (bool) {
        return permissioned().isKeeper(account);
    }
    
    /// @notice Check if an account is a treasury
    /// @param account The account to check
    /// @return True if the account has the treasury role
    function isTreasury(address account) external view virtual returns (bool) {
        return permissioned().isTreasury(account);
    }

    /// @notice Get the admin address
    /// @return The admin address
    function admin() external view virtual returns (address) {
        return permissioned().admin();
    }

    /// @notice Get the treasury address
    /// @return The treasury address
    function treasury() external view virtual returns (address) {
        return permissioned().treasury();
    }

    /// @notice Get all managers
    /// @return The list of managers
    function getManagers() external view virtual returns (address[] memory) {
        return permissioned().getManagers();
    }

    /// @notice Get all keepers
    /// @return The list of keepers
    function getKeepers() external view virtual returns (address[] memory) {
        return permissioned().getKeepers();
    }
}
