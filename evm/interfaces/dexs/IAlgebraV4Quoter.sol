// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// Quoter + Quoter02
interface IAlgebraV4Quoter {
    struct QuoteExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint160 limitSqrtPrice;
    }

    struct QuoteExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint256 amount;
        uint160 limitSqrtPrice;
    }

    function WNativeToken() external view returns (address);
    function algebraSwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata path) external view;
    function factory() external view returns (address);
    function poolDeployer() external view returns (address);
    
    function quoteExactInput(bytes calldata path, uint256 amountInRequired) external returns (
        uint256 amountOut,
        uint256 amountIn,
        uint160[] memory sqrtPriceX96AfterList,
        uint32[] memory initializedTicksCrossedList,
        uint256 gasEstimate,
        uint16[] memory feeList
    );
    
    function quoteExactInputSingle(QuoteExactInputSingleParams calldata params) external returns (
        uint256 amountOut,
        uint256 amountIn,
        uint160 sqrtPriceX96After,
        uint32 initializedTicksCrossed,
        uint256 gasEstimate,
        uint16 fee
    );
    
    function quoteExactOutput(bytes calldata path, uint256 amountOutRequired) external returns (
        uint256 amountOut,
        uint256 amountIn,
        uint160[] memory sqrtPriceX96AfterList,
        uint32[] memory initializedTicksCrossedList,
        uint256 gasEstimate,
        uint16[] memory feeList
    );
    
    function quoteExactOutputSingle(QuoteExactOutputSingleParams calldata params) external returns (
        uint256 amountOut,
        uint256 amountIn,
        uint160 sqrtPriceX96After,
        uint32 initializedTicksCrossed,
        uint256 gasEstimate,
        uint16 fee
    );
}