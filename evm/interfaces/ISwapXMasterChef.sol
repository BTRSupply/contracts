// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/token/ERC721/IERC721.sol";

interface IMasterchef {
    struct PoolInfo {
        uint256 accRewardPerShare;
        uint256 accRewardPerShareExtra;
        uint256 lastRewardTime;
    }
}

interface ISwapXMasterChef {
    function LOCK_DURATION() external view returns (uint256);
    function NFT() external view returns (IERC721);
    function PERCENT_PRECISION() external view returns (uint256);
    function TOKEN() external view returns (IERC20);
    function addKeeper(address[] memory _keepers) external;
    function deposit(uint256[] memory tokenIds) external;
    function distributePeriod() external view returns (uint256);
    function emergencyWithdraw() external;
    function getRightBoarder() external view returns (uint256);
    function getRightBoarderExtra() external view returns (uint256);
    function harvest() external;
    function harvestExtra() external;
    function isKeeper(address) external view returns (bool);
    function lastDistributedTime() external view returns (uint256);
    function lastDistributedTimeExtra() external view returns (uint256);
    function minter() external view returns (address);
    function onERC721Received(address, address, uint256, bytes memory) external pure returns (bytes4);
    function owner() external view returns (address);
    function pendingReward(address _user) external view returns (uint256 pending);
    function pendingRewardExtra(address _user) external view returns (uint256 pending);
    function poolInfo() external view returns (uint256 accRewardPerShare, uint256 accRewardPerShareExtra, uint256 lastRewardTime);
    function removeKeeper(address[] memory _keepers) external;
    function renounceOwnership() external;
    function rewardPerSecond() external view returns (uint256);
    function rewardPerSecondExtra() external view returns (uint256);
    function setDistributionRate(uint256 amount) external;
    function setDistributionRateExtra(uint256 amount) external;
    function setRewardPerSecond(uint256 _rewardPerSecond) external;
    function setRewardPerSecondExtra(uint256 _rewardPerSecondExtra) external;
    function setVestingEscrowShare(uint256 newValue) external;
    function stakedTokenIds(address _user) external view returns (uint256[] memory tokenIds);
    function tokenOwner(uint256) external view returns (address);
    function totalRewards() external view returns (uint256);
    function totalRewardsExtra() external view returns (uint256);
    function transferOwnership(address newOwner) external;
    function updatePool() external returns (IMasterchef.PoolInfo memory pool);
    function userInfo(address) external view returns (uint256 amount, uint256 rewardDebt, uint256 rewardDebtExtra);
    function veShare() external view returns (uint256);
    function vesting() external view returns (address);
    function votingEscrow() external view returns (address);
    function withdraw(uint256[] memory tokenIds) external;
}
