// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibAccessControl} from "../libraries/LibAccessControl.sol";
import {LibSwapper} from "../libraries/LibSwapper.sol";
import {BTRErrors as Errors, BTREvents as Events} from "../libraries/BTREvents.sol";
import {PermissionedFacet} from "./abstract/PermissionedFacet.sol";
import {LibRescuable} from "../libraries/LibRescuable.sol";

/// @title SwapperFacet
/// @notice External interface for on-chain swap calldata execution
/// @dev Implements external functions that leverage the LibSwapper library
contract SwapperFacet is PermissionedFacet {
    using SafeERC20 for IERC20;
    using LibAccessControl for bytes32;
    using LibSwapper for bool;
    using LibSwapper for address;
    using LibRescuable for address;

    /*═══════════════════════════════════════════════════════════════╗
    ║                       CONFIGURATION                            ║
    ╚═══════════════════════════════════════════════════════════════*/

    /// @notice Initialize the Swapper with default settings
    /// @param _restrictCaller Whether to restrict callers
    /// @param _restrictRouter Whether to restrict routers 
    /// @param _approveMax Whether to approve max amount
    function initializeSwapper(
        bool _restrictCaller,
        bool _restrictRouter,
        bool _approveMax
    ) external onlyAdmin {
        LibSwapper.initializeSwapper(_restrictCaller, _restrictRouter, _approveMax);
    }

    /// @notice Sets caller restriction flag
    /// @param _restrictCaller Flag value (true to restrict, false to allow all)
    function setCallerRestriction(bool _restrictCaller) external onlyAdmin {
        _restrictCaller.setCallerRestriction();
    }

    /// @notice Sets router restriction flag
    /// @param _restrictRouter Flag value (true to restrict, false to allow all)
    function setRouterRestriction(bool _restrictRouter) external onlyAdmin {
        _restrictRouter.setRouterRestriction();
    }

    /// @notice Sets input token restriction flag
    /// @param _restrictInput Flag value (true to restrict, false to allow all)
    function setInputRestriction(bool _restrictInput) external onlyAdmin {
        _restrictInput.setInputRestriction();
    }

    /// @notice Sets output token restriction flag
    /// @param _restrictOutput Flag value (true to restrict, false to allow all)
    function setOutputRestriction(bool _restrictOutput) external onlyAdmin {
        _restrictOutput.setOutputRestriction();
    }

    /// @notice Sets approve max flag
    /// @param _approveMax Flag value (true to approve max, false to approve exact amount)
    function setApproveMax(bool _approveMax) external onlyAdmin {
        _approveMax.setApproveMax();
    }

    /// @notice Sets auto revoke flag
    /// @param _autoRevoke Flag value (true to auto revoke, false to keep approval)
    function setAutoRevoke(bool _autoRevoke) external onlyAdmin {
        _autoRevoke.setAutoRevoke();
    }

    /// @notice Adds an address to the whitelist
    /// @param _address Address to whitelist
    function addToWhitelist(address _address) external onlyAdmin {
        _address.addToWhitelist();
    }

    /// @notice Removes an address from the whitelist
    /// @param _address Address to remove from whitelist
    function removeFromWhitelist(address _address) external onlyAdmin {
        _address.removeFromWhitelist();
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                           VIEWS                                ║
    ╚═══════════════════════════════════════════════════════════════*/
    
    /// @notice Checks if an address is whitelisted
    /// @param _address Address to check
    /// @return Whether the address is whitelisted
    function isWhitelisted(address _address) external view returns (bool) {
        return _address.isWhitelisted();
    }

    /// @notice Checks if a caller is restricted
    /// @param _caller Address to check
    /// @return Whether the caller is restricted
    function isCallerRestricted(address _caller) external view returns (bool) {
        return _caller.isCallerRestricted();
    }

    /// @notice Checks if a router is restricted
    /// @param _router Address to check
    /// @return Whether the router is restricted
    function isRouterRestricted(address _router) external view returns (bool) {
        return _router.isRouterRestricted();
    }

    /// @notice Checks if an input token is restricted
    /// @param _input Address to check
    /// @return Whether the input token is restricted
    function isInputRestricted(address _input) external view returns (bool) {
        return _input.isInputRestricted();
    }

    /// @notice Checks if an output token is restricted
    /// @param _output Address to check
    /// @return Whether the output token is restricted
    function isOutputRestricted(address _output) external view returns (bool) {
        return _output.isOutputRestricted();
    }

    /// @notice Checks if should approve max amount
    /// @return Whether to approve max amount
    function isApproveMax() external view returns (bool) {
        return LibSwapper.isApproveMax();
    }

    /// @notice Checks if should auto revoke approvals
    /// @return Whether to auto revoke approvals
    function isAutoRevoke() external view returns (bool) {
        return LibSwapper.isAutoRevoke();
    }

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
        return LibSwapper.executeSwap(
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
        uint256 balance = IERC20(_input).balanceOf(msg.sender);
        if (balance == 0) revert Errors.ZeroValue();
        
        return LibSwapper.executeSwap(
            _input,
            _output,
            balance,
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
        (
            address targetRouter,
            uint256 minAmountOut,
            bytes memory callData
        ) = _params.decodeSwapParams();

        return LibSwapper.executeSwap(
            _input,
            _output,
            _amount,
            minAmountOut,
            targetRouter,
            callData,
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
        uint256 balance = IERC20(_input).balanceOf(address(this));
        if (balance == 0) revert Errors.ZeroValue();
        
        (
            address targetRouter,
            uint256 minAmountOut,
            bytes memory callData
        ) = _params.decodeSwapParams();

        return LibSwapper.executeSwap(
            _input,
            _output,
            balance,
            minAmountOut,
            targetRouter,
            callData,
            msg.sender
        );
    }

    /// @notice Executes multiple swaps
    /// @param _inputs Array of input token addresses
    /// @param _outputs Array of output token addresses
    /// @param _amountsIn Array of input token amounts
    /// @param _minAmountsOut Array of minimum output token amounts
    /// @param _targetRouters Array of router addresses
    /// @param _callDatas Array of encoded routing data
    /// @return received Array of output token amounts received
    /// @return spent Array of input token amounts spent
    function multiSwap(
        address[] calldata _inputs,
        address[] calldata _outputs,
        uint256[] calldata _amountsIn,
        uint256[] calldata _minAmountsOut,
        address[] calldata _targetRouters,
        bytes[] calldata _callDatas
    ) external returns (uint256[] memory received, uint256[] memory spent) {
        uint256 length = _inputs.length;
        if (length == 0 ||
            length != _outputs.length ||
            length != _amountsIn.length ||
            length != _minAmountsOut.length ||
            length != _targetRouters.length ||
            length != _callDatas.length) {
            revert Errors.InvalidParameter();
        }
        
        received = new uint256[](length);
        spent = new uint256[](length);

        for (uint256 i = 0; i < length;) {
            (received[i], spent[i]) = LibSwapper.executeSwap(
                _inputs[i],
                _outputs[i],
                _amountsIn[i],
                _minAmountsOut[i],
                _targetRouters[i],
                _callDatas[i],
                msg.sender
            );
            unchecked { ++i; }
        }
    }

    /// @notice Executes multiple swaps using entire balances
    /// @param _inputs Array of input token addresses
    /// @param _outputs Array of output token addresses
    /// @param _minAmountsOut Array of minimum output token amounts
    /// @param _targetRouters Array of router addresses
    /// @param _callDatas Array of encoded routing data
    /// @return received Array of output token amounts received
    /// @return spent Array of input token amounts spent
    function multiSwapBalances(
        address[] calldata _inputs,
        address[] calldata _outputs,
        uint256[] calldata _minAmountsOut,
        address[] calldata _targetRouters,
        bytes[] calldata _callDatas
    ) external returns (uint256[] memory received, uint256[] memory spent) {
        uint256 length = _inputs.length;
        if (length == 0 ||
            length != _outputs.length ||
            length != _minAmountsOut.length ||
            length != _targetRouters.length ||
            length != _callDatas.length) {
            revert Errors.InvalidParameter();
        }
        
        received = new uint256[](length);
        spent = new uint256[](length);
        
        for (uint256 i = 0; i < length;) {
            uint256 balance = IERC20(_inputs[i]).balanceOf(msg.sender);
            if (balance == 0) {
                unchecked { ++i; }
                continue;
            }
            
            (received[i], spent[i]) = LibSwapper.executeSwap(
                _inputs[i],
                _outputs[i],
                balance,
                _minAmountsOut[i],
                _targetRouters[i],
                _callDatas[i],
                msg.sender
            );
            unchecked { ++i; }
        }
    }

    /// @notice Executes multiple swaps with encoded parameters
    /// @param _inputs Array of input token addresses
    /// @param _outputs Array of output token addresses
    /// @param _amountsIn Array of input token amounts
    /// @param _params Array of encoded swap parameters
    /// @return received Array of output token amounts received
    /// @return spent Array of input token amounts spent
    function decodeAndMultiSwap(
        address[] calldata _inputs,
        address[] calldata _outputs,
        uint256[] calldata _amountsIn,
        bytes[] calldata _params
    ) external returns (uint256[] memory received, uint256[] memory spent) {
        uint256 length = _inputs.length;
        if (length != _outputs.length ||
            length != _amountsIn.length ||
            length != _params.length) {
            revert Errors.InvalidParameter();
        }
        
        received = new uint256[](length);
        spent = new uint256[](length);
        
        for (uint256 i = 0; i < length;) {
            (
                address targetRouter,
                uint256 minAmountOut,
                bytes memory callData
            ) = _params[i].decodeSwapParams();
            
            (received[i], spent[i]) = LibSwapper.executeSwap(
                _inputs[i],
                _outputs[i],
                _amountsIn[i],
                minAmountOut,
                targetRouter,
                callData,
                msg.sender
            );
            unchecked { ++i; }
        }
    }

    /// @notice Executes multiple swaps using entire balances with encoded parameters
    /// @param _inputs Array of input token addresses
    /// @param _outputs Array of output token addresses
    /// @param _params Array of encoded swap parameters
    /// @return received Array of output token amounts received
    /// @return spent Array of input token amounts spent
    function decodeAndMultiSwapBalances(
        address[] calldata _inputs,
        address[] calldata _outputs,
        bytes[] calldata _params
    ) external returns (uint256[] memory received, uint256[] memory spent) {
        uint256 length = _inputs.length;
        if (length != _outputs.length ||
            length != _params.length) {
            revert Errors.InvalidParameter();
        }
        
        received = new uint256[](length);
        spent = new uint256[](length);
        
        for (uint256 i = 0; i < length;) {
            uint256 balance = IERC20(_inputs[i]).balanceOf(msg.sender);
            if (balance == 0) {
                unchecked { ++i; }
                continue;
            }
            (
                address targetRouter,
                uint256 minAmountOut,
                bytes memory callData
            ) = _params[i].decodeSwapParams();
            
            (received[i], spent[i]) = LibSwapper.executeSwap(
                _inputs[i],
                _outputs[i],
                balance,
                minAmountOut,
                targetRouter,
                callData,
                msg.sender
            );
            unchecked { ++i; }
        }
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                          RESCUE FUNCTION                       ║
    ╚═══════════════════════════════════════════════════════════════*/
    
    /// @notice Rescues tokens accidentally sent to this contract
    /// @param _token Token to rescue (use address(1) for native tokens)
    function requestRescue(address _token) external onlyAdmin {
        _token.requestRescue();
    }
}
