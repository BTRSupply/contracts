// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {BTRStorage as S} from "@libraries/BTRStorage.sol";
import {BTRErrors as Errors} from "@libraries/BTREvents.sol";
import {Restrictions, ErrorType} from "@/BTRTypes.sol";

abstract contract NonReentrantFacet {
    modifier nonReentrant() {
        Restrictions storage rs = S.restrictions();
        if (rs.entered) revert Errors.Unauthorized(ErrorType.REENTRANCY);
        rs.entered = true;
        _;
        rs.entered = false;
    }
}
