// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IVeloV3Voter {
    function ve() external view returns (address);
    function vote(
        uint256 _tokenId,
        address[] calldata _poolVote,
        uint256[] calldata _weights
    ) external;
    function gauges(address _pool) external view returns (address);
    function gaugeToFees(address _gauge) external view returns (address);
    function gaugeToBribes(address _gauge) external view returns (address);
    function createGauge(
        address _poolFactory,
        address _pool
    ) external returns (address);
    function distribute(address gauge) external;
    function factoryRegistry() external view returns (address);
    function distribute(address[] memory _gauges) external;
    function isAlive(address _gauge) external view returns (bool);
    function killGauge(address _gauge) external;
    function emergencyCouncil() external view returns (address);
    function claimRewards(address[] memory _gauges) external;
    function claimFees(
        address[] memory _fees,
        address[][] memory _tokens,
        uint256 _tokenId
    ) external;
}
