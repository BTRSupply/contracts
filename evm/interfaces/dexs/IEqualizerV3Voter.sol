// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IEqualizerV3Voter {
    function DURATION() external view returns (uint256);
    function _ve() external view returns (address);
    function attachTokenToGauge(uint256 tokenId, address account) external;
    function base() external view returns (address);
    function bribefactory() external view returns (address);
    function bribes(address) external view returns (address);
    function claimBribes(address[] calldata _bribes, address[][] calldata _tokens, uint256 _tokenId) external;
    function claimEverything(
        address[] calldata _gauges,
        address[][] calldata _gtokens,
        address[] calldata _bribes,
        address[][] calldata _btokens,
        uint256 _tokenId
    ) external;
    function claimRewards(address[] calldata _gauges, address[][] calldata _tokens) external;
    function claimable(address) external view returns (uint256);
    function createGauge(address _pool) external returns (address);
    function createGaugeMultiple(address[] calldata _pools) external returns (address[] memory);
    function customGauges(address) external view returns (address);
    function detachTokenFromGauge(uint256 tokenId, address account) external;
    function distribute(address[] calldata _gauges) external;
    function distribute(address _gauge) external;
    function distribute(uint256 start, uint256 finish) external;
    function distribute() external;
    function distributeFees(uint256 start, uint256 finish) external;
    function distributeFees(address _gauge) external;
    function distributeFees() external;
    function distributeFees(address[] calldata _gauges) external;
    function distributions(uint256, address) external view returns (uint256);
    function emergencyCouncil() external view returns (address);
    function emitDeposit(uint256 tokenId, address account, uint256 amount) external;
    function emitWithdraw(uint256 tokenId, address account, uint256 amount) external;
    function factory() external view returns (address);
    function gaugable(address) external view returns (bool);
    function gaugefactory() external view returns (address);
    function gauges(address) external view returns (address);
    function governor() external view returns (address);
    function index() external view returns (uint256);
    function initialSetup(address[] calldata _tokens, address[] calldata _gaugables, address _minter) external;
    function initialize(address __ve, address _factory, address _gauges, address _bribes) external;
    function isAlive(address) external view returns (bool);
    function isGauge(address) external view returns (bool);
    function isListingsManager(address) external view returns (bool);
    function isWhitelisted(address) external view returns (bool);
    function killGauge(address _gauge) external;
    function lastDistribution(address) external view returns (uint256);
    function lastVoted(uint256) external view returns (uint256);
    function length() external view returns (uint256);
    function minter() external view returns (address);
    function ms() external view returns (address);
    function notifyRewardAmount(uint256 amount) external;
    function pausedGauges(address) external view returns (bool);
    function pokable() external view returns (bool);
    function poke(uint256 _tokenId) external;
    function poolForGauge(address) external view returns (address);
    function poolVote(uint256, uint256) external view returns (address);
    function pools(uint256) external view returns (address);
    function protocolFeesPerMillion() external view returns (uint256);
    function protocolFeesTaker() external view returns (address);
    function removeFromWhitelist(address[] calldata _tokens) external;
    function reset(uint256 _tokenId) external;
    function resetOverride(uint256[] calldata _ids) external;
    function resetOverride(uint256 _tokenId) external;
    function reviveGauge(address _gauge) external;
    function setBribe(address _pool, address _nb) external;
    function setCustomGauge(address[] calldata _g, address[] calldata _cg) external;
    function setEmergencyCouncil(address _council) external;
    function setGaugable(address[] calldata _pools, bool[] calldata _b) external;
    function setGov(address _ms) external;
    function setGovernor(address _governor) external;
    function setListingsManager(address _m, bool _b) external;
    function setMinter(address _m) external;
    function setPausedGauge(address[] calldata _g, bool[] calldata _b) external;
    function setPokable(bool _b) external;
    function setProtocolFeesPerMillion(uint256 _pf) external;
    function setProtocolFeesTaker(address _pft) external;
    function setUnvotablePools(address[] calldata _pools, bool[] calldata _b) external;
    function supplyIndex(address) external view returns (uint256);
    function totalWeight() external view returns (uint256);
    function unvotable(address) external view returns (bool);
    function updateAll() external;
    function updateFor(address[] calldata _gauges) external;
    function updateForRange(uint256 start, uint256 end) external;
    function updateGauge(address _gauge) external;
    function usedWeights(uint256) external view returns (uint256);
    function vote(uint256 tokenId, address[] calldata _poolVote, uint256[] calldata _weights) external;
    function voteResults(uint256, address) external view returns (uint256);
    function voterTurnouts(uint256) external view returns (uint256);
    function votes(uint256, address) external view returns (uint256);
    function weights(address) external view returns (uint256);
    function whitelist(address[] calldata _tokens) external;
}
