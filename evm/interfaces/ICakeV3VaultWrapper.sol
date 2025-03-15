// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ICakeV3VaultWrapper {
    function PRECISION_FACTOR() external view returns (uint256);
    function WRAPPER_FACTORY() external view returns (address);
    function accTokenPerShare() external view returns (uint256);
    function adapterAddr() external view returns (address payable);
    function deposit(uint256 _amount) external;
    function depositRewardAndExpend(uint256 _amount) external;
    function emergencyRewardWithdraw(uint256 _amount) external;
    function emergencyWithdraw() external;
    function endTimestamp() external view returns (uint256);
    function initialize(
        IERC20 _stakedToken,
        IERC20 _rewardToken,
        uint256 _rewardPerSecond,
        uint256 _startTimestamp,
        uint256 _endTimestamp,
        address _admin
    ) external;
    function isInitialized() external view returns (bool);
    function lastRewardTimestamp() external view returns (uint256);
    function mintThenDeposit(uint256 _amount0, uint256 _amount1, bytes calldata _data) external;
    function owner() external view returns (address);
    function pendingReward(address _user) external view returns (uint256);
    function recoverToken(address _token) external;
    function renounceOwnership() external;
    function restart(uint256 _startTimestamp, uint256 _endTimestamp, uint256 _rewardPerSecond) external;
    function rewardPerSecond() external view returns (uint256);
    function rewardToken() external view returns (IERC20);
    function stakedToken() external view returns (IERC20);
    function startTimestamp() external view returns (uint256);
    function stopReward() external;
    function transferOwnership(address newOwner) external;
    function updateAdapterAddress(address _adapterAddr) external;
    function updateRewardPerSecond(uint256 _rewardPerSecond) external;
    function updateStartAndEndTimestamp(uint256 _startTimestamp, uint256 _endTimestamp) external;
    function userInfo(address) external view returns (uint256 amount, uint256 rewardDebt);
    function withdraw(uint256 _amount) external;
    function withdrawThenBurn(uint256 _amount, bytes calldata _data) external;
}
