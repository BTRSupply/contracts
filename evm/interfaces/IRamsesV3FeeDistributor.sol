// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// includes 
interface IRamsesV3FeeDistributor {
    function WEEK() external view returns (uint256);
    function _ve() external view returns (address);
    function _deposit(uint256 amount, uint256 tokenId) external;
    function _burn(uint256 amount, uint256 tokenId) external;
    function balanceOf(uint256) external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256 amount);
    function bribe(address token, uint256 amount) external;
    function earned(address token, uint256 tokenId) external view returns (uint256 reward);
    function earned(address token, address owner) external view returns (uint256 reward);
    function firstPeriod() external view returns (uint256);
    function feeRecipient() external view returns (address);
    function getPeriod() external view returns (uint256);
    function getPeriodReward(uint256 period, uint256 tokenId, address token) external;
    function getPeriodReward(uint256 period, address owner, address token) external;
    function getReward(uint256 tokenId, address[] memory tokens) external;
    function getReward(address owner, address[] memory tokens) external;
    function getRewardForOwner(uint256 tokenId, address[] memory tokens) external;
    function getRewardForOwner(address owner, address[] memory tokens) external;
    function getRewardTokens() external view returns (address[] memory);
    function incentivize(address token, uint256 amount) external;
    function initialize(address _voter) external;
    function isReward(address) external view returns (bool);
    function lastClaimByToken(address, uint256) external view returns (uint256);
    function notifyRewardAmount(address token, uint256 amount) external;
    function recoverRewards(address token, uint256 amount) external;
    function removeReward(address _token) external;
    function rewards(uint256) external view returns (address);
    function tokenTotalSupplyByPeriod(uint256, address) external view returns (uint256);
    function totalVeShareByPeriod(uint256) external view returns (uint256);
    function veShareByPeriod(uint256, uint256) external view returns (uint256);
    function veWithdrawnTokenAmountByPeriod(uint256, uint256, address) external view returns (uint256);
    function voteModule() external view returns (address);
    function voter() external view returns (address);
    function votes(uint256 period) external view returns (uint256 weight);
}
