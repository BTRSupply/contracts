// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// aka. IGaugeDistribution, includes IBribeDistribution
interface IThenaV3FeeDistributor {
    function _deposit(uint256 amount, uint256 tokenId) external;
    function _burn(uint256 amount, uint256 tokenId) external;
    function getRewardForOwner(uint tokenId, address[] memory tokens) external;
    function notifyRewardAmount(address token, uint amount) external;
    function getReward(address account, address[] memory tokens) external;
    function claimFees() external returns (uint claimed0, uint claimed1);
    function left(address token) external view returns (uint);
    function recoverERC20(address tokenAddress, uint256 tokenAmount) external;
    function setOwner(address _owner) external;
    function rewardRate(address _pair) external view returns (uint);
    function balanceOf(address _account) external view returns (uint);
    function isForPair() external view returns (bool);
    function totalSupply() external view returns (uint);
    function earned(address token, address account) external view returns (uint);
    function internal_bribe() external view returns(address);
    function TOKEN() external view returns(address);
}
