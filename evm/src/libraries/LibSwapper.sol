// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccountStatus as AS, ErrorType, Restrictions} from "@/BTRTypes.sol";
import {BTRErrors as Errors, BTREvents as Events} from "@libraries/BTREvents.sol";
import {BTRStorage as S} from "@libraries/BTRStorage.sol";
import {LibAccessControl as AC} from "@libraries/LibAccessControl.sol";
import {LibMaths} from "@libraries/LibMaths.sol";
import {LibManagement as M} from "@libraries/LibManagement.sol";

library LibSwapper {

    using SafeERC20 for IERC20;
    using LibMaths for uint256;

    /*═══════════════════════════════════════════════════════════════╗
    ║                          SWAP LOGIC                            ║
    ╚═══════════════════════════════════════════════════════════════*/

    /// @notice Executes a swap with minimal restrictions - silent, less safe, use with caution
    /// @param _input Input token address
    /// @param _router Router address to execute the swap
    /// @param _callData Encoded swap calldata for the router
    function swap(address _input, address _router, bytes memory _callData) internal {

        if (M.isSwapRouterRestricted(_router)) {
            revert Errors.Unauthorized(ErrorType.ROUTER);
        }

        // Always approve router with max amount
        IERC20(_input).forceApprove(_router, type(uint256).max);

        // Execute swap
        (bool success,) = _router.call(_callData);
        if (!success) revert Errors.RouterError();

        // Revoke allowance if configured
        if (M.isAutoRevoke()) {
            IERC20(_input).forceApprove(_router, 0);
        }
    }

    /// @notice Executes direct swap with exact input amount provided
    /// @param _input Input token address
    /// @param _output Output token address
    /// @param _amountIn Amount of input tokens to swap
    /// @param _minAmountOut Minimum amount of output tokens to receive
    /// @param _router Router address to execute the swap
    /// @param _callData Encoded swap calldata for the router
    /// @param _caller Address of the caller (tokens will be taken from and sent to this address)
    /// @return received Amount of output tokens received
    /// @return spent Amount of input tokens spent
    function swap(
        address _input,
        address _output,
        uint256 _amountIn,
        uint256 _minAmountOut,
        address _router,
        bytes memory _callData,
        address _caller
    ) internal returns (uint256 received, uint256 spent) {
        // Validate access
        if (M.isSwapCallerRestricted(_caller) ||
            M.isSwapRouterRestricted(_router) ||
            M.isSwapInputRestricted(_input) ||
            M.isSwapOutputRestricted(_output)) {
            revert Errors.Unauthorized(ErrorType.ADDRESS);
        }

        IERC20 input = IERC20(_input);
        IERC20 output = IERC20(_output);

        // Get tokens from caller
        input.safeTransferFrom(_caller, address(this), _amountIn);
        uint256 inputBefore = input.balanceOf(address(this));
        uint256 outputBefore = output.balanceOf(_caller);

        // Approve router if needed
        if (input.allowance(address(this), _router) < _amountIn) {
            input.forceApprove(_router, 
                M.isApproveMax() ? type(uint256).max : _amountIn);
        }

        // Execute swap
        (bool success,) = _router.call(_callData);
        if (!success) revert Errors.RouterError();

        // Calculate results
        unchecked {
            received = output.balanceOf(_caller).subMax0(outputBefore);
            spent = inputBefore.subMax0(input.balanceOf(address(this)));
        }

        // Validate output and handle leftovers
        if (received == 0 || spent == 0) revert Errors.UnexpectedOutput();
        if (received < _minAmountOut) revert Errors.SlippageTooHigh();

        // Return leftover tokens to caller
        uint256 leftover = _amountIn.subMax0(spent);
        if (leftover > 0) input.safeTransfer(_caller, leftover);
        
        // Revoke allowance if configured
        if (M.isAutoRevoke()) {
            input.forceApprove(_router, 0);
        }
        emit Events.Swapped(_caller, _input, _output, spent, received);
    }

    /// @notice Execute swap using the caller's full balance of input token
    /// @param _input Input token address
    /// @param _output Output token address
    /// @param _minAmountOut Minimum amount of output tokens to receive
    /// @param _router Router address to execute the swap
    /// @param _callData Encoded swap calldata for the router
    /// @param _caller Address of the caller (tokens will be taken from and sent to this address)
    /// @return received Amount of output tokens received
    /// @return spent Amount of input tokens spent
    function swapBalance(
        address _input,
        address _output,
        uint256 _minAmountOut,
        address _router,
        bytes memory _callData,
        address _caller
    ) internal returns (uint256 received, uint256 spent) {
        uint256 balance = IERC20(_input).balanceOf(_caller);
        if (balance == 0) revert Errors.ZeroValue();
        return swap(
            _input,
            _output,
            balance,
            _minAmountOut,
            _router,
            _callData,
            _caller
        );
    }

    /// @notice Decode swap parameters and execute a swap
    /// @param _input Input token address
    /// @param _output Output token address
    /// @param _amount Amount of input tokens to swap
    /// @param _params Encoded swap parameters
    /// @param _caller Address of the caller (tokens will be taken from and sent to this address)
    /// @return received Amount of output tokens received
    /// @return spent Amount of input tokens spent
    function decodeAndSwap(
        address _input,
        address _output,
        uint256 _amount,
        bytes memory _params,
        address _caller
    ) internal returns (uint256 received, uint256 spent) {
        (
            address router,
            uint256 minAmountOut,
            bytes memory callData
        ) = decodeSwapParams(_params);

        return swap(
            _input,
            _output,
            _amount,
            minAmountOut,
            router,
            callData,
            _caller
        );
    }

    /// @notice Decode swap parameters and execute a swap using the caller's full balance
    /// @param _input Input token address
    /// @param _output Output token address
    /// @param _params Encoded swap parameters
    /// @param _caller Address of the caller (tokens will be taken from and sent to this address)
    /// @return received Amount of output tokens received
    /// @return spent Amount of input tokens spent
    function decodeAndSwapBalance(
        address _input,
        address _output,
        bytes memory _params,
        address _caller
    ) internal returns (uint256 received, uint256 spent) {
        uint256 balance = IERC20(_input).balanceOf(_caller);
        if (balance == 0) revert Errors.ZeroValue();
        (
            address router,
            uint256 minAmountOut,
            bytes memory callData
        ) = decodeSwapParams(_params);
        return swap(
            _input,
            _output,
            balance,
            minAmountOut,
            router,
            callData,
            _caller
        );
    }

    /// @notice Decode swap parameters from encoded bytes
    /// @param _params Encoded swap parameters
    /// @return router Router address to use for the swap
    /// @return minAmount Minimum amount of output tokens to receive
    /// @return callData Encoded swap calldata for the router
    function decodeSwapParams(bytes memory _params) internal pure returns (
        address router,
        uint256 minAmount,
        bytes memory callData
    ) {
        return abi.decode(_params, (address, uint256, bytes));
    }
}
