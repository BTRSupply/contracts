// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {AccountStatus as AS} from "@/BTRTypes.sol";

interface IManagementFacet {
    // Pause-related functions
    function isPaused() external view returns (bool);
    function isPaused(uint32 vaultId) external view returns (bool);
    
    // Account status functions
    function getAccountStatus(address account) external view returns (AS);
    function isWhitelisted(address account) external view returns (bool);
    function isBlacklisted(address account) external view returns (bool);

    // Restriction management functions
    function isSwapCallerRestricted(address caller) external view returns (bool);
    function isSwapRouterRestricted(address router) external view returns (bool);
    function isSwapInputRestricted(address input) external view returns (bool);
    function isSwapOutputRestricted(address output) external view returns (bool);
    function isBridgeInputRestricted(address input) external view returns (bool);
    function isBridgeOutputRestricted(address output) external view returns (bool);
    function isBridgeRouterRestricted(address router) external view returns (bool);
    function isApproveMax() external view returns (bool);
    function isAutoRevoke() external view returns (bool);
    
    // Vault management functions
    function getVersion() external view returns (uint8);
    function getMaxSupply(uint32 vaultId) external view returns (uint256);
    function isRestrictedMint(uint32 vaultId) external view returns (bool);
    function isRestrictedMinter(uint32 vaultId, address minter) external view returns (bool);
} 