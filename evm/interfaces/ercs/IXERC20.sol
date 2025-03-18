// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

/**
 * @title IXERC20
 * @notice Interface for the xERC20 generic cross-chain token ex EIP-7281
 */
interface IXERC20 {
    /**
     * @notice Emitted when the limits for a bridge are set
     */
    event BridgeLimitsSet(uint256 _mintingLimit, uint256 _burningLimit, address indexed _bridge);

    /**
     * @notice Reverts when a bridge with too low of a limit tries to call mint/burn
     */
    error IXERC20_NotHighEnoughLimits();

    /**
    * @notice Updates the limits of any bridge
    * @dev Can only be called by the owner
    * @param _mintingLimit The updated minting limit we are setting to the bridge
    * @param _burningLimit The updated burning limit we are setting to the bridge
    * @param _bridge The address of the bridge we are setting the limits too
    */
    function setLimits(address _bridge, uint256 _mintingLimit, uint256 _burningLimit) external;

    /**
     * @notice Returns the max limit of a minter
     *
     * @param _bridge The bridge we are viewing the limits of
     * @return _limit The limit the bridge has
     */
    function mintingMaxLimitOf(address _bridge) external view returns (uint256 _limit);

    /**
     * @notice Returns the max limit of a bridge
     *
     * @param _bridge the bridge we are viewing the limits of
     * @return _limit The limit the bridge has
     */
    function burningMaxLimitOf(address _bridge) external view returns (uint256 _limit);

    /**
     * @notice Returns the current limit of a minter
     *
     * @param _bridge The bridge we are viewing the limits of
     * @return _limit The limit the minter has
     */
    function mintingCurrentLimitOf(address _bridge) external view returns (uint256 _limit);

    /**
     * @notice Returns the current limit of a bridge
     *
     * @param _bridge the bridge we are viewing the limits of
     * @return _limit The limit the bridge has
     */
    function burningCurrentLimitOf(address _bridge) external view returns (uint256 _limit);

    /**
     * @notice Mints tokens for a user
     * @dev Can only be called by a bridge
     * @param _user The address of the user who needs tokens minted
     * @param _amount The amount of tokens being minted
     */
    function mint(address _user, uint256 _amount) external;

    /**
     * @notice Burns tokens for a user
     * @dev Can only be called by a bridge
     * @param _user The address of the user who needs tokens burned
     * @param _amount The amount of tokens being burned
     */
    function burn(address _user, uint256 _amount) external;
}
