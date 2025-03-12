// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@layerzerolabs/oft-evm/contracts/OFTAdapter.sol";
import "@interfaces/IERC7802.sol";
import "@interfaces/IXERC20.sol";
import { BTRErrors as Errors, BTREvents as Events } from "@libraries/BTREvents.sol";
import "@facets/abstract/PermissionedFacet.sol";

/**
 * @title LayerZeroAdapterFacet
 * @dev Diamond facet that implements cross-chain functionality using LayerZero OFTAdapter.
 * This facet integrates with BTR token to facilitate cross-chain token transfers.
 */
contract LayerZeroAdapterFacet is OFTAdapter, PermissionedFacet {
    // Events
    event TokenAddressSet(address indexed tokenAddress);
    event SendToChainCompleted(uint32 indexed destinationChainId, address indexed sender, address indexed recipient, uint256 amount);
    event ReceiveFromChainCompleted(uint32 indexed sourceChainId, address indexed recipient, uint256 amount);

    // Constants
    uint256 private constant DEFAULT_LIMIT = type(uint256).max;

    /**
     * @dev Initialize the LayerZero Adapter with the required parameters
     * @param _lzEndpoint The LayerZero endpoint contract address
     * @param _token The address of the BTR token contract
     * @param _owner The owner of this adapter (typically the admin)
     */
    function initialize(address _lzEndpoint, address _token, address _owner) external onlyAdmin {
        if (_lzEndpoint == address(0) || _token == address(0)) revert Errors.ZeroAddress();
        
        // Initialize the OFTAdapter base contract
        super._initialize(_token, _lzEndpoint, _owner);
        
        // Register this adapter as a bridge with default limits
        _registerAsBridge(DEFAULT_LIMIT, DEFAULT_LIMIT);
        
        emit TokenAddressSet(_token);
    }
    
    /**
     * @dev Sets the token address and registers as bridge
     * @param _token The new token address
     */
    function setTokenAddress(address _token) external onlyAdmin {
        if (_token == address(0)) revert Errors.ZeroAddress();
        
        // Update the token address in the base contract
        innerToken = IERC20(_token);
        
        // Re-register as bridge with default limits
        _registerAsBridge(DEFAULT_LIMIT, DEFAULT_LIMIT);
        
        emit TokenAddressSet(_token);
    }

    /**
     * @dev Register this adapter as a bridge with the BTR token
     * @param mintLimit The minting limit for this bridge
     * @param burnLimit The burning limit for this bridge
     */
    function registerAsBridge(uint256 mintLimit, uint256 burnLimit) external onlyAdmin {
        _registerAsBridge(mintLimit, burnLimit);
    }

    /**
     * @dev Internal function to register as bridge and set limits
     */
    function _registerAsBridge(uint256 mintLimit, uint256 burnLimit) internal {
        IXERC20 token = IXERC20(address(innerToken));
        token.setLimits(address(this), mintLimit, burnLimit);
    }
    
    /**
     * @dev Override of OFTAdapter's _debitFrom to use BTR's crosschainBurn
     */
    function _debitFrom(
        address _from,
        uint16,
        bytes32,
        uint256 _amount
    ) internal virtual override returns (uint256) {
        IERC7802(address(innerToken)).crosschainBurn(_from, _amount);
        return _amount;
    }

    /**
     * @dev Override of OFTAdapter's _creditTo to use BTR's crosschainMint
     */
    function _creditTo(
        uint16,
        address _toAddress,
        uint256 _amount
    ) internal virtual override returns (uint256) {
        IERC7802(address(innerToken)).crosschainMint(_toAddress, _amount);
        return _amount;
    }
    
    /**
     * @dev Send tokens to another chain using LayerZero
     * @param _dstEid The destination chain ID (endpoint ID)
     * @param _to The recipient address on the destination chain
     * @param _amount The amount of tokens to send
     * @param _refundAddress The address to refund excess gas to
     * @param _zroPaymentAddress The ZRO payment address (usually address(0))
     * @param _adapterParams Additional adapter parameters
     */
    function sendTokens(
        uint32 _dstEid,
        bytes32 _to,
        uint256 _amount,
        address payable _refundAddress,
        address _zroPaymentAddress,
        bytes calldata _adapterParams
    ) external payable {
        // Check if sender is frozen
        if (IXERC20(address(innerToken)).isFrozen(msg.sender)) revert Errors.AddressFrozen();
        
        // Convert bytes32 to address for the recipient
        address recipient = address(uint160(uint256(_to)));
        
        // Call the parent OFTAdapter send function
        super.send{value: msg.value}(
            _dstEid,
            _to,
            _amount,
            _refundAddress,
            _zroPaymentAddress,
            _adapterParams
        );
        
        emit SendToChainCompleted(_dstEid, msg.sender, recipient, _amount);
    }
    
    /**
     * @dev Estimate the fee for sending tokens to another chain
     * @param _dstEid The destination chain ID
     * @param _amount The amount of tokens to send
     * @param _useZro Whether to use ZRO for payment
     * @param _adapterParams Additional adapter parameters
     * @return nativeFee The estimated fee in native token
     * @return zroFee The estimated fee in ZRO token
     */
    function estimateSendFee(
        uint32 _dstEid,
        bytes32 _to,
        uint256 _amount,
        bool _useZro,
        bytes calldata _adapterParams
    ) external view returns (uint256 nativeFee, uint256 zroFee) {
        return super.estimateSendFee(
            _dstEid,
            _to,
            _amount,
            _useZro,
            _adapterParams
        );
    }
    
    /**
     * @dev Called by the endpoint when tokens are received from a remote chain
     * This is a simplified version - in the OFT pattern, this is handled internally
     * by the OFTAdapter, but we're exposing it for clarity and event emission
     * @param _srcEid The source chain ID
     * @param _from The sender address on the source chain
     * @param _to The recipient address on this chain
     * @param _amount The amount of tokens received
     */
    function onReceive(
        uint32 _srcEid,
        bytes32 _from,
        address _to,
        uint256 _amount
    ) external {
        // Ensure only the endpoint can call this
        if (msg.sender != address(endpoint)) revert Errors.NotAuthorized();
        
        // Check if recipient is frozen
        if (IXERC20(address(innerToken)).isFrozen(_to)) revert Errors.AddressFrozen();
        
        emit ReceiveFromChainCompleted(_srcEid, _to, _amount);
    }
    
    /**
     * @dev Set trusted peer information for each chain
     */
    function setPeer(uint32 _dstEid, bytes32 _peer) external onlyAdmin {
        super._setPeer(_dstEid, _peer);
    }
    
    /**
     * @dev Get current minting limit for this bridge
     */
    function getCurrentMintLimit() external view returns (uint256) {
        return IXERC20(address(innerToken)).mintingCurrentLimitOf(address(this));
    }

    /**
     * @dev Get current burning limit for this bridge
     */
    function getCurrentBurnLimit() external view returns (uint256) {
        return IXERC20(address(innerToken)).burningCurrentLimitOf(address(this));
    }
    
    /**
     * @dev Get information about this OFT adapter
     */
    function getInfo() external view returns (address, uint8) {
        return (token(), decimals());
    }
}
