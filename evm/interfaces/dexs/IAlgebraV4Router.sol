// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// SwapRouter + SwapRouter02
interface IAlgebraV4Router {
    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 limitSqrtPrice;
    }

    struct ExactOutputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
    }

    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        address recipient;
        uint256 deadline;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 limitSqrtPrice;
    }

    struct Route {
        address from;
        address to;
        bool stable;
    }

    struct IncreaseLiquidityParams {
        address token0;
        address token1;
        uint256 tokenId;
        uint256 amount0Min;
        uint256 amount1Min;
    }

    struct MintParams {
        address token0;
        address token1;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
    }

    function WNativeToken() external view returns (address);
    function algebraSwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata _data) external;
    function approveMax(address token) external payable;
    function approveMaxMinusOne(address token) external payable;
    function approveZeroThenMax(address token) external payable;
    function approveZeroThenMaxMinusOne(address token) external payable;
    function callPositionManager(bytes calldata data) external payable returns (bytes memory result);
    function checkOracleSlippage(bytes[] calldata paths, uint128[] calldata amounts, uint24 maximumTickDivergence, uint32 secondsAgo) external view;
    function checkOracleSlippage(bytes calldata path, uint24 maximumTickDivergence, uint32 secondsAgo) external view;
    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
    function exactInputSingleSupportingFeeOnTransferTokens(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
    function exactOutput(ExactOutputParams calldata params) external payable returns (uint256 amountIn);
    function exactOutputSingle(ExactOutputSingleParams calldata params) external payable returns (uint256 amountIn);
    function factory() external view returns (address);
    function factoryV2() external view returns (address);
    function getApprovalType(address token, uint256 amount) external returns (uint8);
    function increaseLiquidity(IncreaseLiquidityParams calldata params) external payable returns (bytes memory result);
    function mint(MintParams calldata params) external payable returns (bytes memory result);
    function multicall(bytes32 previousBlockhash, bytes[] calldata data) external payable returns (bytes[] memory);
    function multicall(uint256 deadline, bytes[] calldata data) external payable returns (bytes[] memory);
    function multicall(bytes[] calldata data) external payable returns (bytes[] memory results);
    function poolDeployer() external view returns (address);
    function positionManager() external view returns (address);
    function pull(address token, uint256 value) external payable;
    function refundNativeToken() external payable;
    function selfPermit(address token, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external payable;
    function selfPermitAllowed(address token, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s) external payable;
    function selfPermitAllowedIfNecessary(address token, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s) external payable;
    function selfPermitIfNecessary(address token, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external payable;
    function swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, Route[] calldata routes, address to) external payable returns (uint256 amountOut);
    function sweepToken(address token, uint256 amountMinimum, address recipient) external payable;
    function sweepToken(address token, uint256 amountMinimum) external payable;
    function sweepTokenWithFee(address token, uint256 amountMinimum, uint256 feeBips, address feeRecipient) external payable;
    function sweepTokenWithFee(address token, uint256 amountMinimum, address recipient, uint256 feeBips, address feeRecipient) external payable;
    function unwrapWNativeToken(uint256 amountMinimum, address recipient) external payable;
    function unwrapWNativeToken(uint256 amountMinimum) external payable;
    function unwrapWNativeTokenWithFee(uint256 amountMinimum, address recipient, uint256 feeBips, address feeRecipient) external payable;
    function unwrapWNativeTokenWithFee(uint256 amountMinimum, uint256 feeBips, address feeRecipient) external payable;
    function wrapETH(uint256 value) external payable;
    receive() external payable;
}
