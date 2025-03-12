// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {AccountStatus as AS, ErrorType, ProtocolStorage, SwapperStorage} from "../BTRTypes.sol";
import {BTRErrors as Errors, BTREvents as Events} from "./BTREvents.sol";
import {BTRStorage as S} from "./BTRStorage.sol";
import {LibAccessControl as AC} from "./LibAccessControl.sol";
import {LibBitMask} from "./LibBitMask.sol";
import {LibManagement as M} from "./LibManagement.sol";

library LibSwapper {

    using SafeERC20 for IERC20;
    using LibBitMask for uint256;

    /*═══════════════════════════════════════════════════════════════╗
    ║                          CONSTANTS                             ║
    ╚═══════════════════════════════════════════════════════════════*/

    // Restriction bit positions
    uint8 internal constant RESTRICT_CALLER_BIT = 0;
    uint8 internal constant RESTRICT_ROUTER_BIT = 1;
    uint8 internal constant RESTRICT_INPUT_BIT = 2;
    uint8 internal constant RESTRICT_OUTPUT_BIT = 3;
    uint8 internal constant APPROVE_MAX_BIT = 4;
    uint8 internal constant AUTO_REVOKE_BIT = 5;

    /*═══════════════════════════════════════════════════════════════╗
    ║                          STORAGE ACCESS                        ║
    ╚═══════════════════════════════════════════════════════════════*/

    function getRestrictions() internal view returns (uint256) {
        return S.protocol().swapRestrictions;
    }

    function setRestriction(uint8 _bit, bool _value) internal {
        uint256 restrictions = S.protocol().swapRestrictions;
        S.protocol().swapRestrictions = _value 
            ? restrictions.setBit(_bit)
            : restrictions.resetBit(_bit);
        emit Events.SwapRestrictionUpdated(_bit, _value);
    }

    function setCallerRestriction(bool _value) internal {
        setRestriction(RESTRICT_CALLER_BIT, _value);
    }

    function setRouterRestriction(bool _value) internal {
        setRestriction(RESTRICT_ROUTER_BIT, _value);
    }

    function setInputRestriction(bool _value) internal {
        setRestriction(RESTRICT_INPUT_BIT, _value);
    }

    function setOutputRestriction(bool _value) internal {
        setRestriction(RESTRICT_OUTPUT_BIT, _value);
    }

    function setApproveMax(bool _value) internal {
        setRestriction(APPROVE_MAX_BIT, _value);
    }

    function setAutoRevoke(bool _value) internal {
        setRestriction(AUTO_REVOKE_BIT, _value);
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                        RESTRICTION CHECKS                      ║
    ╚═══════════════════════════════════════════════════════════════*/

    function isRestricted(uint8 _bit, address _address) internal view returns (bool) {
        return getRestrictions().getBit(_bit) && !M.isWhitelisted(_address);
    }

    function isCallerRestricted(address _caller) internal view returns (bool) {
        return isRestricted(RESTRICT_CALLER_BIT, _caller);
    }

    function isRouterRestricted(address _router) internal view returns (bool) {
        return isRestricted(RESTRICT_ROUTER_BIT, _router);
    }

    function isInputRestricted(address _input) internal view returns (bool) {
        return isRestricted(RESTRICT_INPUT_BIT, _input);
    }

    function isOutputRestricted(address _output) internal view returns (bool) {
        return isRestricted(RESTRICT_OUTPUT_BIT, _output);
    }

    function isApproveMax() internal view returns (bool) {
        return getRestrictions().getBit(APPROVE_MAX_BIT);
    }

    function isAutoRevoke() internal view returns (bool) {
        return getRestrictions().getBit(AUTO_REVOKE_BIT);
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                          SWAP LOGIC                            ║
    ╚═══════════════════════════════════════════════════════════════*/

    function executeSwap(
        address _input,
        address _output,
        uint256 _amountIn,
        uint256 _minAmountOut,
        address _router,
        bytes memory _callData,
        address _caller
    ) internal returns (uint256 received, uint256 spent) {
        // Validate access
        ProtocolStorage storage ps = S.protocol();
        uint256 r = ps.swapRestrictions;
        if ((r.getBit(RESTRICT_CALLER_BIT) && ps.accountStatus[_caller] != AS.WHITELIST) ||
            (r.getBit(RESTRICT_ROUTER_BIT) && ps.accountStatus[_router] != AS.WHITELIST) ||
            (r.getBit(RESTRICT_INPUT_BIT) && ps.accountStatus[_input] != AS.WHITELIST) ||
            (r.getBit(RESTRICT_OUTPUT_BIT) && ps.accountStatus[_output] != AS.WHITELIST)) {
            revert Errors.Unauthorized(ErrorType.ADDRESS);
        }

        IERC20 input = IERC20(_input);
        IERC20 output = IERC20(_output);

        // Get tokens from caller
        input.safeTransferFrom(_caller, address(this), _amountIn);
        uint256 inputBefore = input.balanceOf(address(this));
        uint256 outputBefore = output.balanceOf(_caller);

        // Approve router if needed
        uint256 allowance = input.allowance(address(this), _router);
        if (allowance < _amountIn) {
            input.forceApprove(_router, 
                restrictions.getBit(APPROVE_MAX_BIT) ? type(uint256).max : _amountIn);
        }

        // Execute swap
        (bool success,) = _router.call(_callData);
        if (!success) revert Errors.RouterError();

        // Calculate results
        unchecked {
            received = output.balanceOf(_caller) - outputBefore;
            spent = inputBefore - input.balanceOf(address(this));
        }

        // Validate output and handle leftovers
        if (received == 0 || spent == 0) revert Errors.UnexpectedOutput();
        if (received < _minAmountOut) revert Errors.SlippageTooHigh();

        // Return leftover tokens to caller
        uint256 leftover = _amountIn - spent;
        if (leftover > 0) input.safeTransfer(_caller, leftover);
        
        // Revoke allowance if configured
        if (restrictions.getBit(AUTO_REVOKE_BIT)) {
            input.forceApprove(_router, 0);
        }

        emit Events.Swapped(_caller, _input, _output, spent, received);
    }

    function decodeSwapParams(bytes memory _params) internal pure returns (
        address router,
        uint256 minAmount,
        bytes memory callData
    ) {
        return abi.decode(_params, (address, uint256, bytes));
    }

    function initializeSwapper(
        bool _restrictCaller,
        bool _restrictRouter,
        bool _approveMax
    ) internal {
        uint256 restrictions = 0;
        if (_restrictCaller) restrictions = restrictions.setBit(RESTRICT_CALLER_BIT);
        if (_restrictRouter) restrictions = restrictions.setBit(RESTRICT_ROUTER_BIT);
        if (_approveMax) restrictions = restrictions.setBit(APPROVE_MAX_BIT);
        S.protocol().swapRestrictions = restrictions;
        
        // Emit events
        emit Events.SwapRestrictionUpdated(RESTRICT_CALLER_BIT, _restrictCaller);
        emit Events.SwapRestrictionUpdated(RESTRICT_ROUTER_BIT, _restrictRouter);
        emit Events.SwapRestrictionUpdated(APPROVE_MAX_BIT, _approveMax);
    }

    function validateSwap(
        address input,
        address output,
        address router,
        address caller
    ) internal view {
        uint256 restrictions = getRestrictions();
        
        if ((restrictions.getBit(RESTRICT_CALLER_BIT) && M.getAccountStatus(caller) != AS.WHITELIST) ||
            (restrictions.getBit(RESTRICT_ROUTER_BIT) && M.getAccountStatus(router) != AS.WHITELIST) ||
            (restrictions.getBit(RESTRICT_INPUT_BIT) && M.getAccountStatus(input) != AS.WHITELIST) ||
            (restrictions.getBit(RESTRICT_OUTPUT_BIT) && M.getAccountStatus(output) != AS.WHITELIST)) {
            revert Errors.CallRestricted();
        }
    }
}
