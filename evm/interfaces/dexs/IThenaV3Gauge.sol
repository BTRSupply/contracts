// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// includes IBribe
interface IThenaV3Gauge {
    struct Reward {
        uint256 periodFinish;
        uint256 rewardsPerEpoch;
        uint256 lastUpdateTime; 
    }
    function deposit(uint amount, uint tokenId) external;
    function withdraw(uint amount, uint tokenId) external;
    function getRewardForOwner(uint tokenId, address[] memory tokens) external;
    function notifyRewardAmount(address token, uint amount) external;
    function getReward(address account, address[] memory tokens) external;
    function getReward(address account) external;
    function claimFees() external returns (uint claimed0, uint claimed1);
    function left(address token) external view returns (uint);
    function rewardsListLength() external view returns (uint);
    function supplyNumCheckpoints() external view returns (uint);
    function getEpochStart() external pure returns (uint);
    function getNextEpochStart() external pure returns (uint);
    function getPriorSupplyIndex(uint timestamp) external view returns (uint);
    function rewardTokens(uint index) external view returns (address);
    function rewardsPerEpoch(address token,uint ts) external view returns (uint);
    function supplyCheckpoints(uint _index) external view returns(uint timestamp, uint supplyd);
    function earned(uint tokenId, address token) external view returns (uint);
    function earned(address token, address account) external view returns (uint);
    function earned(address account) external view returns (uint);
    function firstBribeTimestamp() external view returns(uint);
    function totalSupplyAt(uint256 _timestamp) external view returns (uint256);
    function balanceOfAt(uint256 tokenId, uint256 _timestamp) external view returns (uint256);
    function rewardData(address _token, uint256 ts) external view returns(Reward memory _Reward);
    function rewardRate(address _pair) external view returns (uint);
    function rewardRate() external view returns (uint);
    function balanceOf(address _account) external view returns (uint);
    function isForPair() external view returns (bool);
    function totalSupply() external view returns (uint);
}
