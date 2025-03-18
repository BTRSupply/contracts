// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IUniV4Quoter {
    struct QuoteExactParams {
        address exactCurrency;
        PathKey[] path;
        uint128 exactAmount;
    }

    struct PathKey {
        address intermediateCurrency;
        uint24 fee;
        int24 tickSpacing;
        address hooks;
        bytes hookData;
    }

    struct QuoteExactSingleParams {
        PoolKey poolKey;
        bool zeroForOne;
        uint128 exactAmount;
        bytes hookData;
    }

    struct PoolKey {
        address currency0;
        address currency1;
        uint24 fee;
        int24 tickSpacing;
        address hooks;
    }
    function poolManager() external view returns (address);
    function _quoteExactInput(QuoteExactParams calldata params) external returns (bytes memory);
    function _quoteExactInputSingle(QuoteExactSingleParams calldata params) external returns (bytes memory);
    function _quoteExactOutput(QuoteExactParams calldata params) external returns (bytes memory);
    function _quoteExactOutputSingle(QuoteExactSingleParams calldata params) external returns (bytes memory);
    function quoteExactInput(QuoteExactParams calldata params) external returns (uint256 amountOut, uint256 gasEstimate);
    function quoteExactInputSingle(QuoteExactSingleParams calldata params) external returns (uint256 amountOut, uint256 gasEstimate);
    function quoteExactOutput(QuoteExactParams calldata params) external returns (uint256 amountIn, uint256 gasEstimate);
    function quoteExactOutputSingle(QuoteExactSingleParams calldata params) external returns (uint256 amountIn, uint256 gasEstimate);
    function unlockCallback(bytes calldata data) external returns (bytes memory);
}