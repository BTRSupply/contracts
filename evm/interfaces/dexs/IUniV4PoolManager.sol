// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IUniV4PoolManager {

    struct PoolKey {
        address currency0;
        address currency1;
        uint24 fee;
        int24 tickSpacing;
        address hooks;
    }

    struct ModifyLiquidityParams {
        int24 tickLower;
        int24 tickUpper;
        int256 liquidityDelta;
        bytes32 salt;
    }

    struct SwapParams {
        bool zeroForOne;
        int256 amountSpecified;
        uint160 sqrtPriceLimitX96;
    }

    function allowance(address owner, address spender, uint256 id) external view returns (uint256 amount);
    function approve(address spender, uint256 id, uint256 amount) external returns (bool);
    function balanceOf(address owner, uint256 id) external view returns (uint256 balance);
    function burn(address from, uint256 id, uint256 amount) external;
    function clear(address currency, uint256 amount) external;
    function collectProtocolFees(address recipient, address currency, uint256 amount) external returns (uint256 amountCollected);
    function donate(PoolKey calldata key, uint256 amount0, uint256 amount1, bytes calldata hookData) external returns (int256 delta);
    function extsload(bytes32 slot) external view returns (bytes32);
    function extsload(bytes32 startSlot, uint256 nSlots) external view returns (bytes32[] memory);
    function extsload(bytes32[] calldata slots) external view returns (bytes32[] memory);
    function exttload(bytes32[] calldata slots) external view returns (bytes32[] memory);
    function exttload(bytes32 slot) external view returns (bytes32);
    function initialize(PoolKey calldata key, uint160 sqrtPriceX96) external returns (int24 tick);
    function isOperator(address owner, address operator) external view returns (bool isOperator);
    function mint(address to, uint256 id, uint256 amount) external;
    function modifyLiquidity(PoolKey calldata key, ModifyLiquidityParams calldata params, bytes calldata hookData) external returns (int256 callerDelta, int256 feesAccrued);
    function owner() external view returns (address);
    function protocolFeeController() external view returns (address);
    function protocolFeesAccrued(address currency) external view returns (uint256 amount);
    function setOperator(address operator, bool approved) external returns (bool);
    function setProtocolFee(PoolKey calldata key, uint24 newProtocolFee) external;
    function setProtocolFeeController(address controller) external;
    function settle() external payable returns (uint256);
    function settleFor(address recipient) external payable returns (uint256);
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
    function swap(PoolKey calldata key, SwapParams calldata params, bytes calldata hookData) external returns (int256 swapDelta);
    function sync(address currency) external;
    function take(address currency, address to, uint256 amount) external;
    function transfer(address receiver, uint256 id, uint256 amount) external returns (bool);
    function transferFrom(address sender, address receiver, uint256 id, uint256 amount) external returns (bool);
    function transferOwnership(address newOwner) external;
    function unlock(bytes calldata data) external returns (bytes memory result);
    function updateDynamicLPFee(PoolKey calldata key, uint24 newDynamicLPFee) external;
}
