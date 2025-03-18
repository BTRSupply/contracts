// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IVeloV3Voter} from "@interfaces/IVeloV3Voter.sol";
import {IVeloV3Pool} from "@interfaces/dexs/IVeloV3Pool.sol";

interface IVeloV3Gauge {
    function nft() external view returns (address);
    function voter() external view returns (IVeloV3Voter);
    function pool() external view returns (IVeloV3Pool);
    function gaugeFactory() external view returns (address);
    function feesVotingReward() external view returns (address);
    function periodFinish() external view returns (uint256);
    function rewardRate() external view returns (uint256);
    function rewards(uint256 tokenId) external view returns (uint256);
    function lastUpdateTime(uint256 tokenId) external view returns (uint256);
    function rewardRateByEpoch(uint256) external view returns (uint256);
    function fees0() external view returns (uint256);
    function fees1() external view returns (uint256);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function tickSpacing() external view returns (int24);
    function left() external view returns (uint256 _left);
    function rewardToken() external view returns (address);
    function isPool() external view returns (bool);
    function rewardGrowthInside(uint256 tokenId) external view returns (uint256);
    function initialize(address _pool, address _feesVotingReward, address _rewardToken, address _voter, address _nft, address _token0, address _token1, int24 _tickSpacing, bool _isPool) external;
    function earned(address token, uint256 tokenId) external view returns (uint256);
    function getReward(address account) external;
    function getReward(uint256 tokenId) external;
    function getReward(uint256 tokenId, address[] memory tokens) external;
    function notifyRewardAmount(uint256 amount) external;
    function notifyRewardAmount(address token, uint256 amount) external;
    function notifyRewardWithoutClaim(uint256 amount) external;
    function deposit(uint256 tokenId) external;
    function withdraw(uint256 tokenId) external;
    function stakedValues(address depositor) external view returns (uint256[] memory);
    function stakedByIndex(address depositor, uint256 index) external view returns (uint256);
    function stakedContains(address depositor, uint256 tokenId) external view returns (bool);
    function stakedLength(address depositor) external view returns (uint256);
}