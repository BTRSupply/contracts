// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {BTRStorage as S} from "../../libraries/BTRStorage.sol";
import {BTRErrors as Errors} from "../../libraries/BTREvents.sol";
import {ProtocolStorage} from "../../BTRTypes.sol";
import {ErrorType} from "../../BTRTypes.sol";

/// @title NonReentrantFacet
/// @notice Abstract contract that provides reentrancy protection
abstract contract NonReentrantFacet {

    /// @notice Prevents reentrancy attacks
    modifier nonReentrant() {

        ProtocolStorage storage ps = S.protocol();
        // Check if we're already in a reentrant call
        if (ps.entered) revert Errors.Unauthorized(ErrorType.REENTRANCY);

        // Mark as entered
        ps.entered = true;
        // Execute the function
        _;
        // Mark as not entered
        ps.entered = false;
    }
}
