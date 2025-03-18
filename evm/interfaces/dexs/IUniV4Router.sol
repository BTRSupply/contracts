// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IUniV4Router {
    struct RouterParameters {
        address permit2;
        address weth9;
        address v2Factory;
        address v3Factory;
        bytes32 pairInitCodeHash;
        bytes32 poolInitCodeHash;
        address v4PoolManager;
        address v3NFTPositionManager;
        address v4PositionManager;
    }
    function V3_POSITION_MANAGER() external view returns (address);
    function V4_POSITION_MANAGER() external view returns (address);
    function execute(bytes calldata commands, bytes[] calldata inputs) external payable;
    function execute(bytes calldata commands, bytes[] calldata inputs, uint256 deadline) external payable;
    function msgSender() external view returns (address);
    function poolManager() external view returns (address);
    function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external;
    function unlockCallback(bytes calldata data) external returns (bytes memory);
    receive() external payable;
}
