// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IUniV4PoolManager} from "@interfaces/IUniV4PoolManager.sol";
import {IUniV4ERC721PermitV4} from "@interfaces/IUniV4Utils.sol";

interface IUniV4PositionManager is IUniV4ERC721PermitV4 {
    struct PoolKey {
        address currency0;
        address currency1;
        uint24 fee;
        int24 tickSpacing;
        address hooks;
    }
    function WETH9() external view returns (address); // wrapped gas token
    function getPoolAndPositionInfo(uint256 tokenId) external view returns (PoolKey memory poolKey, uint256 info);
    function getPositionLiquidity(uint256 tokenId) external view returns (uint128 liquidity);
    function initializePool(PoolKey memory key, uint160 sqrtPriceX96) external payable returns (int24);
    function modifyLiquidities(bytes memory unlockData, uint256 deadline) external payable;
    function modifyLiquiditiesWithoutUnlock(bytes memory actions, bytes[] memory params) external payable;
    function multicall(bytes[] memory data) external payable returns (bytes[] memory results);
    function nextTokenId() external view returns (uint256);
    function poolKeys(bytes25 poolId) external view returns (address currency0, address currency1, uint24 fee, int24 tickSpacing, address hooks);
    function poolManager() external view returns (IUniV4PoolManager);
    function positionInfo(uint256 tokenId) external view returns (uint256 info);
    function subscribe(uint256 tokenId, address newSubscriber, bytes memory data) external payable;
    function subscriber(uint256 tokenId) external view returns (address);
    function tokenDescriptor() external view returns (address);
    function tokenURI(uint256 tokenId) external view returns (string memory);
    function unlockCallback(bytes memory data) external returns (bytes memory);
    function unsubscribe(uint256 tokenId) external payable;
    function unsubscribeGasLimit() external view returns (uint256);
    
    // IERC20Metadata
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    
    receive() external payable;
}
