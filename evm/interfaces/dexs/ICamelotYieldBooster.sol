// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface ICamelotYieldBooster {
    function MAX_TOTAL_ALLOCATION_FLOOR() external view returns (uint256);
    function allocate(address userAddress, uint256 amount, bytes calldata data) external;
    function deallocate(address userAddress, uint256 amount, bytes calldata data) external;
    function deallocateAllFromPool(address userAddress, uint256 tokenId) external;
    function emergencyWithdraw(address token) external;
    function forceDeallocate() external;
    function forcedDeallocationStatus() external view returns (bool);
    function getExpectedMultiplier(uint256 maxBoostMultiplier, uint256 lpAmount, uint256 totalLpSupply, uint256 userAllocation, uint256 poolTotalAllocation) external view returns (uint256);
    function getMultiplier(address poolAddress, uint256 maxBoostMultiplier, uint256 lpAmount, uint256 totalLpSupply, uint256 userAllocation) external view returns (uint256);
    function getPoolTotalAllocation(address poolAddress) external view returns (uint256);
    function getUserPosition(address userAddress, address poolAddress, uint256 index) external view returns (uint256);
    function getUserPositionAllocation(address userAddress, address poolAddress, uint256 tokenId) external view returns (uint256);
    function getUserPositionsLength(address userAddress, address poolAddress) external view returns (uint256);
    function getUserTotalAllocation(address userAddress) external view returns (uint256);
    function owner() external view returns (address);
    function renounceOwnership() external;
    function setTotalAllocationFloor(uint256 floor) external;
    function totalAllocation() external view returns (uint256);
    function totalAllocationFloor() external view returns (uint256);
    function transferOwnership(address newOwner) external;
    function updateForcedDeallocationStatus(bool status) external;
    function usersPositionsAllocation(address, address, uint256) external view returns (uint256);
    function xGrailToken() external view returns (address);
}
