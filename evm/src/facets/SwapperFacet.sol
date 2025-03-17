// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {LibDiamond} from "@libraries/LibDiamond.sol";
import {LibAccessControl} from "@libraries/LibAccessControl.sol";
import {LibSwapper as SW} from "@libraries/LibSwapper.sol";
import {BTRErrors as Errors, BTREvents as Events} from "@libraries/BTREvents.sol";
import {PermissionedFacet} from "@facets/abstract/PermissionedFacet.sol";
import {LibRescue} from "@libraries/LibRescue.sol";
import {LibManagement as M} from "@libraries/LibManagement.sol";
import {BTRStorage as S} from "@libraries/BTRStorage.sol";
import {AccountStatus as AS} from "@/BTRTypes.sol";

/// @title SwapperFacet
/// @notice External interface for on-chain swap calldata execution
/// @dev Implements external functions that leverage the LibSwapper library
contract SwapperFacet is PermissionedFacet {
    using SafeERC20 for IERC20;
    using LibAccessControl for bytes32;
    using LibRescue for address;

    /*═══════════════════════════════════════════════════════════════╗
    ║                          SWAP FUNCTIONS                        ║
    ╚═══════════════════════════════════════════════════════════════*/

    /// @notice Executes a single swap
    /// @param _input Address of the input token
    /// @param _output Address of the output token
    /// @param _amountIn Amount of input tokens to swap
    /// @param _minAmountOut Minimum amount of output tokens to receive
    /// @param _targetRouter Address of the router to be used for the swap
    /// @param _callData Encoded routing data to be passed to the router
    /// @return received Amount of output tokens received
    /// @return spent Amount of input tokens spent
    function swap(
        address _input,
        address _output,
        uint256 _amountIn,
        uint256 _minAmountOut,
        address _targetRouter,
        bytes calldata _callData
    ) external returns (uint256 received, uint256 spent) {
        return SW.swap(
            _input,
            _output,
            _amountIn,
            _minAmountOut,
            _targetRouter,
            _callData,
            msg.sender
        );
    }

    /// @notice Executes a swap using the entire balance of input token
    /// @param _input Address of the input token
    /// @param _output Address of the output token
    /// @param _minAmountOut Minimum amount of output tokens to receive
    /// @param _targetRouter Address of the router to be used for the swap
    /// @param _callData Encoded routing data to be passed to the router
    /// @return received Amount of output tokens received
    /// @return spent Amount of input tokens spent
    function swapBalance(
        address _input,
        address _output,
        uint256 _minAmountOut,
        address _targetRouter,
        bytes calldata _callData
    ) external returns (uint256 received, uint256 spent) {
        return SW.swapBalance(
            _input,
            _output,
            _minAmountOut,
            _targetRouter,
            _callData,
            msg.sender
        );
    }

    /// @notice Executes a swap with encoded parameters
    /// @param _input Address of the input token
    /// @param _output Address of the output token
    /// @param _amount Amount of input tokens to swap
    /// @param _params Encoded swap parameters
    /// @return received Amount of output tokens received
    /// @return spent Amount of input tokens spent
    function decodeAndSwap(
        address _input,
        address _output,
        uint256 _amount,
        bytes memory _params
    ) external returns (uint256 received, uint256 spent) {
        return SW.decodeAndSwap(
            _input,
            _output,
            _amount,
            _params,
            msg.sender
        );
    }

    /// @notice Executes a swap with the entire balance using encoded parameters
    /// @param _input Address of the input token
    /// @param _output Address of the output token
    /// @param _params Encoded swap parameters
    /// @return received Amount of output tokens received
    /// @return spent Amount of input tokens spent
    function decodeAndSwapBalance(
        address _input,
        address _output,
        bytes memory _params
    ) external returns (uint256 received, uint256 spent) {
        return SW.decodeAndSwapBalance(
            _input,
            _output,
            _params,
            msg.sender
        );
    }
}
