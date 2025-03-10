// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20Metadata} from "@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {LibAccessControl as AC} from "./LibAccessControl.sol";
import {BTRErrors as Errors, BTREvents as Events} from "./BTREvents.sol";
import {ErrorType} from "../BTRTypes.sol";

/// @title LibRescuable
/// @notice Library for token rescue functionality
/// @dev Shared logic for rescuing tokens accidentally sent to contract
library LibRescuable {
    using SafeERC20 for IERC20Metadata;

    /*═══════════════════════════════════════════════════════════════╗
    ║                              TYPES                             ║
    ╚═══════════════════════════════════════════════════════════════*/

    struct RescueRequest {
        uint64 timestamp;
        address receiver;
    }

    struct RescuableStorage {
        mapping(address => RescueRequest) rescueRequests;
        uint64 rescueTimelock;
        uint64 rescueValidity;
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                           CONSTANTS                            ║
    ╚═══════════════════════════════════════════════════════════════*/

    uint64 public constant DEFAULT_RESCUE_TIMELOCK = 2 days;
    uint64 public constant DEFAULT_RESCUE_VALIDITY = 7 days;
    uint64 public constant MIN_RESCUE_TIMELOCK = 1 days;
    uint64 public constant MAX_RESCUE_TIMELOCK = 7 days;
    uint64 public constant MIN_RESCUE_VALIDITY = 1 days;
    uint64 public constant MAX_RESCUE_VALIDITY = 30 days;

    // Diamond storage pattern - unique storage slot for rescue data
    bytes32 private constant RESCUABLE_STORAGE_POSITION = keccak256("btr.vault.rescue.storage");

    /*═══════════════════════════════════════════════════════════════╗
    ║                             STORAGE                            ║
    ╚═══════════════════════════════════════════════════════════════*/

    /// @dev Get the RescuableStorage struct from diamond storage
    function rescuableStorage() internal pure returns (RescuableStorage storage rs) {
        bytes32 position = RESCUABLE_STORAGE_POSITION;
        assembly {
            rs.slot := position
        }
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                             VIEWS                              ║
    ╚═══════════════════════════════════════════════════════════════*/

    /// @notice Get the rescue request for a specific token
    /// @param token Token address - use address(1) for native tokens (ETH)
    /// @return receiver Recipient address for the rescue
    /// @return timestamp When the rescue was requested
    /// @return status 0=none, 1=locked, 2=unlocked, 3=expired
    function getRescueRequest(address token) internal view returns (
        address receiver,
        uint64 timestamp,
        uint8 status
    ) {
        RescuableStorage storage rs = rescuableStorage();
        RescueRequest memory req = rs.rescueRequests[token];
        
        receiver = req.receiver;
        timestamp = req.timestamp;
        
        if (req.timestamp == 0) {
            status = 0; // No rescue request
        } else if (block.timestamp < (req.timestamp + rs.rescueTimelock)) {
            status = 1; // Locked
        } else if (block.timestamp <= (req.timestamp + rs.rescueTimelock + rs.rescueValidity)) {
            status = 2; // Unlocked and valid
        } else {
            status = 3; // Expired
        }
    }

    /// @notice Check if a rescue request is currently locked
    /// @param token Token to check
    /// @return Whether the rescue request is locked
    function isRescueLocked(address token) internal view returns (bool) {
        RescuableStorage storage rs = rescuableStorage();
        RescueRequest memory req = rs.rescueRequests[token];
        return req.timestamp != 0 && block.timestamp < (req.timestamp + rs.rescueTimelock);
    }

    /// @notice Check if a rescue request has expired
    /// @param token Token to check
    /// @return Whether the rescue request has expired
    function isRescueExpired(address token) internal view returns (bool) {
        RescuableStorage storage rs = rescuableStorage();
        RescueRequest memory req = rs.rescueRequests[token];
        return req.timestamp != 0 && block.timestamp > (req.timestamp + rs.rescueTimelock + rs.rescueValidity);
    }

    /// @notice Check if a rescue request is unlocked and valid
    /// @param token Token to check
    /// @return Whether the rescue request is unlocked and valid
    function isRescueUnlocked(address token) internal view returns (bool) {
        RescuableStorage storage rs = rescuableStorage();
        RescueRequest memory req = rs.rescueRequests[token];
        uint256 expiryTime = req.timestamp + rs.rescueTimelock + rs.rescueValidity;
        return req.timestamp != 0 && 
               block.timestamp >= (req.timestamp + rs.rescueTimelock) && 
               block.timestamp <= expiryTime;
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                             LOGIC                              ║
    ╚═══════════════════════════════════════════════════════════════*/

    /// @notice Initialize the rescue configuration with default values
    /// @dev Sets the default timelock and validity periods
    function initialize() internal {
        RescuableStorage storage rs = rescuableStorage();
        rs.rescueTimelock = DEFAULT_RESCUE_TIMELOCK;
        rs.rescueValidity = DEFAULT_RESCUE_VALIDITY;
    }

    /// @notice Request a rescue for a specific token
    /// @param token Token to be rescued - use address(1) for native tokens (ETH)
    function requestRescue(address token) internal {
        // Check if token is valid
        if (token == address(0)) {
            revert Errors.ZeroAddress();
        }

        // Check if token is already being rescued
        RescuableStorage storage rs = rescuableStorage();
        RescueRequest storage request = rs.rescueRequests[token];
        if (request.timestamp != 0) {
            revert Errors.AlreadyExists(ErrorType.RESCUE);
        }

        // Create rescue request
        request.timestamp = uint64(block.timestamp);
        request.receiver = msg.sender;

        emit Events.RescueRequested(token, msg.sender, request.timestamp);
    }

    /// @notice Execute a rescue for a specific token
    /// @param token Token to be rescued - use address(1) for native tokens (ETH)
    function executeRescue(address token) internal {
        // Check if token is valid
        if (token == address(0)) {
            revert Errors.ZeroAddress();
        }

        // Get rescue request
        RescuableStorage storage rs = rescuableStorage();
        RescueRequest storage request = rs.rescueRequests[token];

        // Check if rescue request exists
        if (request.timestamp == 0) {
            revert Errors.NotFound(ErrorType.RESCUE);
        }

        // Check if rescue is still locked
        if (block.timestamp < request.timestamp + rs.rescueTimelock) {
            revert Errors.Locked();
        }

        // Check if rescue has expired
        if (block.timestamp > request.timestamp + rs.rescueTimelock + rs.rescueValidity) {
            revert Errors.Expired(ErrorType.RESCUE);
        }

        // Get token balance
        uint256 balance;
        if (token == address(1)) {
            balance = address(this).balance;
        } else {
            balance = IERC20Metadata(token).balanceOf(address(this));
        }

        // Check if there's anything to rescue
        if (balance == 0) {
            revert Errors.ZeroValue();
        }

        // Clear rescue request
        delete rs.rescueRequests[token];

        // Transfer tokens
        if (token == address(1)) {
            (bool success, ) = request.receiver.call{value: balance}("");
            if (!success) {
                revert Errors.Failed(ErrorType.TRANSFER);
            }
        } else {
            IERC20Metadata(token).safeTransfer(request.receiver, balance);
        }

        emit Events.RescueExecuted(token, request.receiver, balance);
    }

    /// @notice Cancel a rescue request
    /// @param token Token for which to cancel the rescue request
    /// @param caller Address calling the cancel function
    function cancelRescue(address token, address caller) internal {
        // Check if token is valid
        if (token == address(0)) {
            revert Errors.ZeroAddress();
        }

        // Get rescue request
        RescuableStorage storage rs = rescuableStorage();
        RescueRequest storage request = rs.rescueRequests[token];

        // Check if rescue request exists
        if (request.timestamp == 0) {
            revert Errors.NotFound(ErrorType.RESCUE);
        }

        // Check if caller is the requester or has admin role
        if (caller != request.receiver && !AC.hasRole(AC.ADMIN_ROLE, caller)) {
            revert Errors.Unauthorized(ErrorType.RESCUE);
        }

        // Clear rescue request
        delete rs.rescueRequests[token];

        emit Events.RescueCancelled(token, caller);
    }
}
