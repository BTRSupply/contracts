// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {BTRStorage as S} from "./BTRStorage.sol";
import {BTRErrors as Errors, BTREvents as Events} from "./BTREvents.sol";
import {LibBitMask} from "./LibBitMask.sol";
import {LibAccessControl} from "./LibAccessControl.sol";
import {SwapperStorage} from "../BTRTypes.sol";

/// @title LibSwapper
/// @notice Library for on-chain swap calldata execution
/// @dev Implements swap functionality that can be used across facets
library LibSwapper {
    using SafeERC20 for IERC20;
    using LibBitMask for uint256;

    /*═══════════════════════════════════════════════════════════════╗
    ║                          CONSTANTS                             ║
    ╚═══════════════════════════════════════════════════════════════*/

    // Restriction bit positions
    uint8 constant RESTRICT_CALLER_BIT = 0;
    uint8 constant RESTRICT_ROUTER_BIT = 1;
    uint8 constant RESTRICT_INPUT_BIT = 2;
    uint8 constant RESTRICT_OUTPUT_BIT = 3;
    uint8 constant APPROVE_MAX_BIT = 4;
    uint8 constant AUTO_REVOKE_BIT = 5;

    /*═══════════════════════════════════════════════════════════════╗
    ║                          STORAGE ACCESS                        ║
    ╚═══════════════════════════════════════════════════════════════*/

    /// @dev Get the SwapperStorage struct from diamond storage
    function swapperStorage() internal pure returns (SwapperStorage storage) {
        return S.swapper();
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                           RESTRICTION                          ║
    ╚═══════════════════════════════════════════════════════════════*/

    /// @notice Set a restriction flag by bit position
    /// @param _bit The bit position to modify
    /// @param _value The boolean value to set
    function setRestriction(uint8 _bit, bool _value) internal {
        SwapperStorage storage ss = swapperStorage();
        ss.restrictions = _value 
            ? ss.restrictions.setBit(_bit)
            : ss.restrictions.resetBit(_bit);
        emit Events.SwapRestrictionUpdated(_bit, _value);
    }

    /// @notice Set caller restriction flag
    /// @param _value Flag value (true to restrict, false to allow all)
    function setCallerRestriction(bool _value) internal {
        setRestriction(RESTRICT_CALLER_BIT, _value);
    }

    /// @notice Set router restriction flag
    /// @param _value Flag value (true to restrict, false to allow all)
    function setRouterRestriction(bool _value) internal {
        setRestriction(RESTRICT_ROUTER_BIT, _value);
    }

    /// @notice Set input token restriction flag
    /// @param _value Flag value (true to restrict, false to allow all)
    function setInputRestriction(bool _value) internal {
        setRestriction(RESTRICT_INPUT_BIT, _value);
    }

    /// @notice Set output token restriction flag
    /// @param _value Flag value (true to restrict, false to allow all)
    function setOutputRestriction(bool _value) internal {
        setRestriction(RESTRICT_OUTPUT_BIT, _value);
    }

    /// @notice Set approve max flag
    /// @param _value Flag value (true to approve max, false to approve exact amount)
    function setApproveMax(bool _value) internal {
        setRestriction(APPROVE_MAX_BIT, _value);
    }

    /// @notice Set auto revoke flag
    /// @param _value Flag value (true to auto revoke, false to keep approval)
    function setAutoRevoke(bool _value) internal {
        setRestriction(AUTO_REVOKE_BIT, _value);
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                          WHITELIST                             ║
    ╚═══════════════════════════════════════════════════════════════*/

    /// @notice Add an address to the whitelist
    /// @param _address Address to whitelist
    function addToWhitelist(address _address) internal {
        if (_address == address(0)) revert Errors.ZeroAddress();
        SwapperStorage storage ss = swapperStorage();
        ss.whitelist[_address] = true;
        emit Events.AddressWhitelisted(_address);
    }

    /// @notice Remove an address from the whitelist
    /// @param _address Address to remove from whitelist
    function removeFromWhitelist(address _address) internal {
        SwapperStorage storage ss = swapperStorage();
        ss.whitelist[_address] = false;
        emit Events.AddressRemovedFromWhitelist(_address);
    }

    /// @notice Check if an address is whitelisted
    /// @param _address Address to check
    /// @return Whether the address is whitelisted
    function isWhitelisted(address _address) internal view returns (bool) {
        return swapperStorage().whitelist[_address];
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                        RESTRICTION CHECKS                      ║
    ╚═══════════════════════════════════════════════════════════════*/

    /// @notice Check if a restriction is enabled and the address is not whitelisted
    /// @param _bit Bit position to check
    /// @param _address Address to check
    /// @return Whether the restriction applies
    function isRestricted(uint8 _bit, address _address) internal view returns (bool) {
        SwapperStorage storage ss = swapperStorage();
        return ss.restrictions.getBit(_bit) && !isWhitelisted(_address);
    }

    /// @notice Check if a caller is restricted
    /// @param _caller Address to check
    /// @return Whether the caller is restricted
    function isCallerRestricted(address _caller) internal view returns (bool) {
        return isRestricted(RESTRICT_CALLER_BIT, _caller);
    }

    /// @notice Check if a router is restricted
    /// @param _router Address to check
    /// @return Whether the router is restricted
    function isRouterRestricted(address _router) internal view returns (bool) {
        return isRestricted(RESTRICT_ROUTER_BIT, _router);
    }

    /// @notice Check if an input token is restricted
    /// @param _input Address to check
    /// @return Whether the input token is restricted
    function isInputRestricted(address _input) internal view returns (bool) {
        return isRestricted(RESTRICT_INPUT_BIT, _input);
    }

    /// @notice Check if an output token is restricted
    /// @param _output Address to check
    /// @return Whether the output token is restricted
    function isOutputRestricted(address _output) internal view returns (bool) {
        return isRestricted(RESTRICT_OUTPUT_BIT, _output);
    }

    /// @notice Check if should approve max amount
    /// @return Whether to approve max amount
    function isApproveMax() internal view returns (bool) {
        return swapperStorage().restrictions.getBit(APPROVE_MAX_BIT);
    }

    /// @notice Check if should auto revoke approvals
    /// @return Whether to auto revoke approvals
    function isAutoRevoke() internal view returns (bool) {
        return swapperStorage().restrictions.getBit(AUTO_REVOKE_BIT);
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                          SWAP LOGIC                            ║
    ╚═══════════════════════════════════════════════════════════════*/

    /// @notice Execute a swap with provided parameters
    /// @param _input Input token address
    /// @param _output Output token address
    /// @param _amountIn Amount of input tokens to swap
    /// @param _minAmountOut Minimum amount of output tokens to receive
    /// @param _targetRouter Target router to use for the swap
    /// @param _callData Encoded swap calldata
    /// @param _caller Address of the caller (usually msg.sender)
    /// @return received Amount of output tokens received
    /// @return spent Amount of input tokens spent
    function executeSwap(
        address _input,
        address _output,
        uint256 _amountIn,
        uint256 _minAmountOut,
        address _targetRouter,
        bytes memory _callData,
        address _caller
    ) internal returns (uint256 received, uint256 spent) {
        // Check restrictions in a single conditional
        if (isInputRestricted(_input) || isOutputRestricted(_output) || 
            isRouterRestricted(_targetRouter) || isCallerRestricted(_caller)) {
            revert Errors.CallRestricted();
        }

        IERC20 input = IERC20(_input);
        IERC20 output = IERC20(_output);

        // Transfer tokens from caller to this contract
        input.safeTransferFrom(_caller, address(this), _amountIn);

        // Record balances before swap
        uint256 inputBefore = input.balanceOf(address(this));
        uint256 outputBefore = output.balanceOf(_caller);

        // Approve router if needed
        uint256 allowance = input.allowance(address(this), _targetRouter);
        if (allowance < _amountIn) {
            input.forceApprove(
                _targetRouter,
                isApproveMax() ? type(uint256).max : _amountIn
            );
        }

        // Execute swap
        (bool ok, ) = _targetRouter.call(_callData);
        if (!ok) revert Errors.RouterError();

        // Calculate amounts
        unchecked {
            received = output.balanceOf(_caller) - outputBefore;
            spent = inputBefore - input.balanceOf(address(this));
        }

        // Validate swap results
        if (spent == 0 || received == 0) revert Errors.UnexpectedOutput();
        if (received < _minAmountOut) revert Errors.SlippageTooHigh();

        // Return leftover tokens to caller
        uint256 leftover = _amountIn - spent;
        if (leftover > 0) {
            input.safeTransfer(_caller, leftover);
        }

        // Revoke approval if needed
        if (isAutoRevoke()) {
            input.forceApprove(_targetRouter, 0);
        }

        emit Events.Swapped(_caller, _input, _output, spent, received);
    }

    /// @notice Helper function to decode swap parameters
    /// @param _params Encoded swap parameters
    /// @return target Router address
    /// @return minAmount Minimum output amount
    /// @return callData Encoded routing data
    function decodeSwapParams(
        bytes memory _params
    ) internal pure returns (
        address target,
        uint256 minAmount,
        bytes memory callData
    ) {
        return abi.decode(_params, (address, uint256, bytes));
    }

    /// @notice Initialize the swapper with default settings
    /// @param _restrictCaller Whether to restrict callers
    /// @param _restrictRouter Whether to restrict routers
    /// @param _approveMax Whether to approve max token amounts
    function initializeSwapper(
        bool _restrictCaller,
        bool _restrictRouter,
        bool _approveMax
    ) internal {
        SwapperStorage storage ss = swapperStorage();
        
        // Set initial restrictions (optimized to a single write)
        uint256 restrictions = 0;
        if (_restrictCaller) restrictions = restrictions.setBit(RESTRICT_CALLER_BIT);
        if (_restrictRouter) restrictions = restrictions.setBit(RESTRICT_ROUTER_BIT);
        if (_approveMax) restrictions = restrictions.setBit(APPROVE_MAX_BIT);
        ss.restrictions = restrictions;
        
        // Emit events
        emit Events.SwapRestrictionUpdated(RESTRICT_CALLER_BIT, _restrictCaller);
        emit Events.SwapRestrictionUpdated(RESTRICT_ROUTER_BIT, _restrictRouter);
        emit Events.SwapRestrictionUpdated(APPROVE_MAX_BIT, _approveMax);
    }
}
