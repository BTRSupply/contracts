// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IThenaV3RewardsDistributor {
    function checkpoint_token() external;
    function checkpoint_total_supply() external;
    function claim(uint256 _tokenId) external returns (uint256);
    function claim_many(uint256[] calldata _tokenIds) external returns (bool);
    function claimable(uint256 _tokenId) external view returns (uint256);
    function depositor() external view returns (address);
    function increaseOrRemoveAllowances(bool _what) external;
    function last_token_time() external view returns (uint256);
    function last_week() external view returns (uint256);
    function lockAddress(address) external view returns (bool);
    function owner() external view returns (address);
    function setDepositor(address _depositor) external;
    function setOwner(address _owner) external;
    function start_time() external view returns (uint256);
    function time_cursor() external view returns (uint256);
    function time_cursor_of(uint256) external view returns (uint256);
    function timestamp() external view returns (uint256);
    function token() external view returns (address);
    function token_claimed() external view returns (uint256);
    function tokens_per_week(uint256) external view returns (uint256);
    function total_distributed() external view returns (uint256);
    function ve_supply(uint256) external view returns (uint256);
    function voting_escrow() external view returns (address);
    function withdrawERC20(address _token) external;
}
