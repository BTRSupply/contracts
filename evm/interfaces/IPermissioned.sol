// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IPermissioned {
    // Role constants
    function ADMIN_ROLE() external view returns (bytes32);
    function MANAGER_ROLE() external view returns (bytes32);
    function KEEPER_ROLE() external view returns (bytes32);
    function TREASURY_ROLE() external view returns (bytes32);
    
    // Role checking functions
    function hasRole(bytes32 role, address account) external view returns (bool);
    function checkRole(bytes32 role) external view;
    function checkRole(bytes32 role, address account) external view;
    
    // Convenience role functions
    function isAdmin(address account) external view returns (bool);
    function isManager(address account) external view returns (bool);
    function isKeeper(address account) external view returns (bool);
    function isTreasury(address account) external view returns (bool);

    // Role member accessor functions
    function admin() external view returns (address);
    function treasury() external view returns (address);
    function getManagers() external view returns (address[] memory);
    function getKeepers() external view returns (address[] memory);

    // Blacklist functions
    function isBlacklisted(address account) external view returns (bool);
    function isWhitelisted(address account) external view returns (bool);
}
