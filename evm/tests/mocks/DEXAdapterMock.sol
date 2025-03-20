// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

contract DEXAdapterMock {
    // Mock functions for DEX adapter interactions
    function mintRange(bytes32 poolId, int24 tickLower, int24 tickUpper, uint256 amount0, uint256 amount1) 
        external 
        returns (uint256 mintAmount0, uint256 mintAmount1) 
    {
        // Mock implementation - just return the inputs
        return (amount0, amount1);
    }
    
    function burnRange(bytes32 poolId, int24 tickLower, int24 tickUpper, uint256 burnAmount)
        external
        returns (uint256 amount0, uint256 amount1)
    {
        // Mock implementation - return some arbitrary amounts
        return (burnAmount / 2, burnAmount / 2);
    }
    
    function collectFees(bytes32 poolId, int24 tickLower, int24 tickUpper)
        external
        returns (uint256 amount0, uint256 amount1)
    {
        // Mock implementation - return arbitrary fee amounts
        return (1e17, 2e17); // 0.1 and 0.2 tokens
    }
    
    function getPool(bytes32 poolId) external pure returns (address) {
        // Mock implementation - return a dummy address
        return address(uint160(uint256(poolId)));
    }
    
    function getLiquidity(bytes32 poolId, int24 tickLower, int24 tickUpper) external pure returns (uint128) {
        // Mock implementation - return a dummy value
        return uint128(uint256(poolId)) + uint128(uint256(uint(tickLower))) + uint128(uint256(uint(tickUpper)));
    }
    
    function getPositionAmounts(bytes32 poolId, int24 tickLower, int24 tickUpper, uint128 liquidity)
        external
        pure
        returns (uint256 amount0, uint256 amount1)
    {
        // Mock implementation - return values based on inputs
        return (
            uint256(liquidity) * 2,
            uint256(liquidity) * 3
        );
    }
    
    function swap(bytes32 poolId, bool zeroForOne, uint256 amountSpecified, uint160 sqrtPriceLimitX96)
        external
        returns (uint256 amount0, uint256 amount1)
    {
        // Mock implementation - return some values based on inputs
        if (zeroForOne) {
            return (amountSpecified, amountSpecified * 2);
        } else {
            return (amountSpecified * 2, amountSpecified);
        }
    }
} 