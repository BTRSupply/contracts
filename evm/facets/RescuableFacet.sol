// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {LibAccessControl as AC} from "../libraries/AC.sol";
import {LibRescuable as R} from "../libraries/R.sol";
import {BTRErrors as Errors, BTREvents as Events} from "../libraries/BTREvents.sol";
import {PermissionedFacet} from "./PermissionedFacet.sol";

/// @title Rescuable Facet
/// @notice Provides external interface for token rescue functionality
/// @dev Uses LibRescuable for the core logic
contract RescuableFacet is PermissionedFacet {

    using R for address;

    /*═══════════════════════════════════════════════════════════════╗
    ║                             VIEWS                              ║
    ╚═══════════════════════════════════════════════════════════════*/

    /// @notice Get the rescue request for a specific token
    /// @param token Token address - use address(1) for native tokens (ETH)
    /// @return receiver Recipient address for the rescue
    /// @return timestamp When the rescue was requested
    /// @return status 0=none, 1=locked, 2=unlocked, 3=expired
    function getRescueRequest(address token) external view returns (
        address receiver,
        uint64 timestamp,
        uint8 status
    ) {
        return token.getRescueRequest();
    }

    /// @notice Check if a rescue request is currently locked
    /// @param token Token to check
    /// @return Whether the rescue request is locked
    function isRescueLocked(address token) external view returns (bool) {
        return token.isRescueLocked();
    }

    /// @notice Check if a rescue request has expired
    /// @param token Token to check
    /// @return Whether the rescue request has expired
    function isRescueExpired(address token) external view returns (bool) {
        return token.isRescueExpired();
    }

    /// @notice Check if a rescue request is unlocked and valid
    /// @param token Token to check
    /// @return Whether the rescue request is unlocked and valid
    function isRescueUnlocked(address token) external view returns (bool) {
        return token.isRescueUnlocked();
    }

    /// @notice Get current rescue timelock and validity periods
    /// @return timelock Current rescue timelock period
    /// @return validity Current rescue validity period
    function getRescueConfig() external view returns (uint64 timelock, uint64 validity) {
        R.RescuableStorage storage rs = R.rescuableStorage();
        return (rs.rescueTimelock, rs.rescueValidity);
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                       RESCUE FUNCTIONS                         ║
    ╚═══════════════════════════════════════════════════════════════*/

    /// @notice Set rescue timelock and validity periods
    /// @param timelock New timelock period in seconds
    /// @param validity New validity period in seconds 
    function setRescueConfig(uint64 timelock, uint64 validity) external onlyAdmin {
        if (timelock < R.MIN_RESCUE_TIMELOCK || timelock > R.MAX_RESCUE_TIMELOCK ||
            validity < R.MIN_RESCUE_VALIDITY || validity > R.MAX_RESCUE_VALIDITY) {
            revert Errors.OutOfBounds();
        }

        R.RescuableStorage storage rs = R.rescuableStorage();
        rs.rescueTimelock = timelock;
        rs.rescueValidity = validity;

        emit Events.RescueConfigUpdated(timelock, validity);
    }

    /// @notice Request a rescue for a specific token
    /// @param token Token to be rescued - use address(1) for native tokens (ETH)
    function requestRescue(address token) external onlyAdmin {
        token.requestRescue();
    }

    /// @notice Execute a rescue for a specific token
    /// @param token Token to be rescued - use address(1) for native tokens (ETH)
    function executeRescue(address token) external onlyManager {
        token.executeRescue();
    }

    /// @notice Cancel a pending rescue request
    /// @param token Token for which to cancel the rescue request
    function cancelRescue(address token) external {
        token.cancelRescue(msg.sender);
    }

    function initialize() external {
        R.initialize();
    }
}
