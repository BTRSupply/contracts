// SPDX-License-Identifier: MIT
// cf. https://github.com/code-423n4/2024-10-ramses-exchange/blob/main/contracts
pragma solidity 0.8.28;

// includes GaugeV3
interface IRamsesV3Gauge {
    struct Reward {
        uint256 rewardRate;
        uint256 periodFinish;
        uint256 lastUpdateTime;
        uint256 rewardPerTokenStored;
    }
    function rewardsList() external view returns (address[] memory _rewards);
    function rewardsListLength() external view returns (uint256 _length);
    function lastTimeRewardApplicable(address token) external view returns (uint256 ltra);
    function rewardData(address token) external view returns (Reward memory data);
    function earned(address token, address account) external view returns (uint256 _reward);
    function getReward(address account, address[] calldata tokens) external;
    function getReward(address owner, uint256 index, int24 tickLower, int24 tickUpper, address[] memory tokens, address receiver) external;
    function rewardPerToken(address token) external view returns (uint256 rpt);
    function depositAll() external;
    function depositFor(address recipient, uint256 amount) external;
    function deposit(uint256 amount) external;
    function withdrawAll() external;
    function withdraw(uint256 amount) external;
    function left(address token) external view returns (uint256);
    function whitelistReward(address _reward) external;
    function removeRewardWhitelist(address _reward) external;
    function notifyRewardAmount(address token, uint256 amount) external;
    function firstPeriod() external returns (uint256);
    function tokenTotalSupplyByPeriod(uint256 period, address token) external view returns (uint256);
    function rewardRate(address token) external view returns (uint256);
    function periodClaimedAmount(uint256 period, bytes32 _positionHash, address reward) external view returns (uint256);
    function lastClaimByToken(address token, bytes32 _positionHash) external view returns (uint256);
    function rewards(uint256 index) external view returns (address);
    function isReward(address reward) external view returns (bool);
    function getRewardTokens() external view returns (address[] memory);
    function positionHash(address owner, uint256 index, int24 tickLower, int24 tickUpper) external pure returns (bytes32);
    function earned(address token, uint256 tokenId) external view returns (uint256 reward);
    function periodEarned(uint256 period, address token, uint256 tokenId) external view returns (uint256);
    function periodEarned(uint256 period, address token, address owner, uint256 index, int24 tickLower, int24 tickUpper) external view returns (uint256);
    function cachePeriodEarned(uint256 period, address token, address owner, uint256 index, int24 tickLower, int24 tickUpper, bool caching) external returns (uint256);
    function getPeriodReward(uint256 period, address[] calldata tokens, uint256 tokenId, address receiver) external;
    function getPeriodReward(uint256 period, address[] calldata tokens, address owner, uint256 index, int24 tickLower, int24 tickUpper, address receiver) external;
    function getRewardForOwner(uint256 tokenId, address[] memory tokens) external;
    function addRewards(address reward) external;
    function removeRewards(address reward) external;
    function notifyRewardAmountForPeriod(address token, uint256 amount, uint256 period) external;
    function notifyRewardAmountNextPeriod(address token, uint256 amount) external;
}
