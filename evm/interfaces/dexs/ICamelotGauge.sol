// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// aka. Staking contract/Dividends v2
interface ICamelotGauge {
    function DEFAULT_CYCLE_DIVIDENDS_PERCENT() external view returns (uint256);
    function MAX_CYCLE_DIVIDENDS_PERCENT() external view returns (uint256);
    function MAX_DISTRIBUTED_TOKENS() external view returns (uint256);
    function MIN_CYCLE_DIVIDENDS_PERCENT() external view returns (uint256);
    function addDividendsToPending(address token, uint256 amount) external;
    function allocate(address userAddress, uint256 amount, bytes calldata data) external;
    function currentCycleStartTime() external view returns (uint256);
    function cycleDurationSeconds() external view returns (uint256);
    function deallocate(address userAddress, uint256 amount, bytes calldata data) external;
    function disableDistributedToken(address token) external;
    function distributedToken(uint256 index) external view returns (address);
    function distributedTokensLength() external view returns (uint256);
    function dividendsInfo(address token) external view returns (
        uint256 currentDistributionAmount,
        uint256 currentCycleDistributedAmount,
        uint256 pendingAmount,
        uint256 distributedAmount,
        uint256 accDividendsPerShare,
        uint256 lastUpdateTime,
        uint256 cycleDividendsPercent,
        bool distributionDisabled
    );
    function emergencyWithdraw(address token) external;
    function emergencyWithdrawAll() external;
    function enableDistributedToken(address token) external;
    function harvestAllDividends() external;
    function harvestDividends(address token) external;
    function isDistributedToken(address token) external view returns (bool);
    function massUpdateDividendsInfo() external;
    function nextCycleStartTime() external view returns (uint256);
    function owner() external view returns (address);
    function pendingDividendsAmount(address token, address userAddress) external view returns (uint256);
    function removeTokenFromDistributedTokens(address tokenToRemove) external;
    function renounceOwnership() external;
    function totalAllocation() external view returns (uint256);
    function transferOwnership(address newOwner) external;
    function updateCurrentCycleStartTime() external;
    function updateCycleDividendsPercent(address token, uint256 percent) external;
    function updateDividendsInfo(address token) external;
    function users(address token, address user) external view returns (uint256 pendingDividends, uint256 rewardDebt);
    function usersAllocation(address user) external view returns (uint256);
    function xGrailToken() external view returns (address);
}
