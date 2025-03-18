// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IIntegralPool {
    function DOMAIN_TYPEHASH() external view returns (bytes32);
    function MINIMUM_LIQUIDITY() external view returns (uint256);
    function PERMIT_TYPEHASH() external view returns (bytes32);
    function allowance(address, address) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function burn(address to) external returns (uint256 amount0Out, uint256 amount1Out);
    function burnFee() external view returns (uint256);
    function collect(address to) external;
    function decimals() external view returns (uint8);
    function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool);
    function factory() external view returns (address);
    function getDepositAmount0In(uint256 amount0, bytes calldata data) external view returns (uint256);
    function getDepositAmount1In(uint256 amount1, bytes calldata data) external view returns (uint256);
    function getDomainSeparator() external view returns (bytes32);
    function getFees() external view returns (uint256, uint256);
    function getReserves() external view returns (uint112, uint112);
    function getSwapAmount0In(uint256 amount1Out, bytes calldata data) external view returns (uint256);
    function getSwapAmount0Out(uint256 amount1In, bytes calldata data) external view returns (uint256);
    function getSwapAmount1In(uint256 amount0Out, bytes calldata data) external view returns (uint256);
    function getSwapAmount1Out(uint256 amount0In, bytes calldata data) external view returns (uint256);
    function increaseAllowance(address spender, uint256 addedValue) external returns (bool);
    function initialize(address _token0, address _token1, address _oracle, address _trader) external;
    function mint(address to) external returns (uint256 liquidityOut);
    function mintFee() external view returns (uint256);
    function name() external view returns (string memory);
    function nonces(address) external view returns (uint256);
    function oracle() external view returns (address);
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;
    function setBurnFee(uint256 fee) external;
    function setMintFee(uint256 fee) external;
    function setOracle(address _oracle) external;
    function setSwapFee(uint256 fee) external;
    function setTrader(address _trader) external;
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
    function swapFee() external view returns (uint256);
    function symbol() external view returns (string memory);
    function sync() external;
    function token0() external view returns (address);
    function token1() external view returns (address);
    function totalSupply() external view returns (uint256);
    function trader() external view returns (address);
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}
