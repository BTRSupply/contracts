// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Permissioned} from "@abstract/Permissioned.sol";
import {AccountStatus as AS} from "@/BTRTypes.sol";
import {IManagementFacet} from "@interfaces/IManagementFacet.sol";

/// @title Managed
/// @notice Abstract contract for external contracts to use management functionality from the Diamond
abstract contract Managed is Permissioned {
    
    /// @dev Access to management functions via interface
    function management() internal view returns (IManagementFacet) {
        return IManagementFacet(diamond);
    }

    // ========== Account Status ==========

    /// @notice Get the status of an account
    /// @param account The account to check
    /// @return The account status
    function getAccountStatus(address account) public view returns (AS) {
        return management().getAccountStatus(account);
    }

    // ========== System State ==========

    /// @notice Check if the system is paused
    /// @return True if the system is paused
    function isPaused() public view returns (bool) {
        return management().isPaused();
    }
}
