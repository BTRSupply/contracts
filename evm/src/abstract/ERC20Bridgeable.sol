// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@interfaces/ercs/IERC7802.sol";
import "@interfaces/ercs/IXERC20.sol";
import "@abstract/Permissioned.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title ERC20Bridgeable
 * @notice Abstract ERC20 token that implements cross-chain bridging functionality
 * @dev Combines ERC20, ERC20Permit, ERC165, ReentrancyGuard with IERC7802 and IXERC20 for cross-chain bridging
 */
abstract contract ERC20Bridgeable is 
    ERC20,
    ERC20Permit,
    ERC165,
    ReentrancyGuard,
    IERC7802,
    IXERC20,
    Permissioned
{
    // Custom Errors
    error ZeroAddress();
    error ZeroAmount();
    error InvalidRateLimitPeriod();
    error MaxSupplyExceeded();
    error InsufficientAllowance();
    error TransferRestricted();
    error BridgeNotFound();

    // Bridge configuration
    struct Bridge {
        // Mint limits
        uint256 mintingLimit;
        uint256 mintedInPeriod;
        uint256 lastMintResetTime;

        // Burn limits
        uint256 burningLimit;
        uint256 burnedInPeriod;
        uint256 lastBurnResetTime;
    }

    // Custom Events
    event RateLimitPeriodUpdated(uint256 newPeriod);
    event TransferBlocked(address indexed from, address indexed to, uint256 value);

    // Period for rate limiting
    uint256 public constant MIN_RATE_LIMIT_PERIOD = 1 days;
    uint256 public constant MAX_RATE_LIMIT_PERIOD = 365 days;
    uint256 public rateLimitPeriod = 1 days;

    // Mapping to track approved bridges
    mapping(address => Bridge) public bridges;

    /**
     * @dev Constructor for the ERC20Bridgeable token
     * @param name Token name
     * @param symbol Token symbol
     * @param _diamond Address of the diamond contract for access control
     */
    constructor(
        string memory name,
        string memory symbol,
        address _diamond
    ) ERC20(name, symbol) ERC20Permit(name) Permissioned(_diamond) {
        if (_diamond == address(0)) revert ZeroAddress();
    }

    /**
     * @dev Function modifier to check if a bridge is approved
     */
    modifier onlyApprovedBridge() {
        if (bridges[msg.sender].mintingLimit == 0) revert IXERC20_NotHighEnoughLimits();
        _;
    }

    /**
     * @dev Function modifier to check if transfer is allowed between accounts
     * @param from The sender address
     * @param to The receiver address
     */
    modifier transferAllowed(address from, address to) {
        if (!_canTransfer(from, to)) {
            emit TransferBlocked(from, to, 0);
            revert TransferRestricted();
        }
        _;
    }

    /**
     * @dev Set the rate limit period
     * @param _newPeriod The new rate limit period in seconds
     */
    function setRateLimitPeriod(uint256 _newPeriod) external onlyAdmin {
        if (_newPeriod < MIN_RATE_LIMIT_PERIOD || _newPeriod > MAX_RATE_LIMIT_PERIOD) {
            revert InvalidRateLimitPeriod();
        }
        rateLimitPeriod = _newPeriod;
        emit RateLimitPeriodUpdated(_newPeriod);
    }

    /**
     * @dev Remove approval for a bridge
     * @param bridge The bridge address to remove
     */
    function removeBridge(address bridge) external onlyAdmin {
        if (bridge == address(0)) revert ZeroAddress();
        if (bridges[bridge].mintingLimit == 0) revert BridgeNotFound();
        
        bridges[bridge].mintingLimit = 0;
        bridges[bridge].burningLimit = 0;
        emit BridgeLimitsSet(0, 0, bridge);
    }

    /**
     * @dev Set limits for a bridge, automatically enabling it
     * @param bridge The bridge address
     * @param mintingLimit The maximum amount that can be minted in a period
     * @param burningLimit The maximum amount that can be burned in a period
     */
    function setLimits(
        address bridge,
        uint256 mintingLimit,
        uint256 burningLimit
    ) external onlyAdmin {
        // Ensure bridge exists
        if (bridge == address(0)) revert ZeroAddress();

        // Set the limits
        bridges[bridge].mintingLimit = mintingLimit;
        bridges[bridge].burningLimit = burningLimit;

        // Emit the standard IXERC20 event
        emit BridgeLimitsSet(mintingLimit, burningLimit, bridge);
    }

    /**
     * @dev Manually update a bridge's mint limit
     * @param bridge The bridge address
     * @param newLimit The new minting limit
     * @param resetCounter Whether to reset the current period counter
     */
    function updateMintLimit(address bridge, uint256 newLimit, bool resetCounter) external onlyAdmin {
        if (bridge == address(0)) revert ZeroAddress();
        if (bridges[bridge].mintingLimit == 0) revert BridgeNotFound();
        
        Bridge storage bridgeConfig = bridges[bridge];
        bridgeConfig.mintingLimit = newLimit;
        
        if (resetCounter) {
            bridgeConfig.mintedInPeriod = 0;
            bridgeConfig.lastMintResetTime = block.timestamp;
        }
        
        emit BridgeLimitsSet(newLimit, bridgeConfig.burningLimit, bridge);
    }
    
    /**
     * @dev Manually update a bridge's burn limit
     * @param bridge The bridge address
     * @param newLimit The new burning limit
     * @param resetCounter Whether to reset the current period counter
     */
    function updateBurnLimit(address bridge, uint256 newLimit, bool resetCounter) external onlyAdmin {
        if (bridge == address(0)) revert ZeroAddress();
        if (bridges[bridge].burningLimit == 0) revert BridgeNotFound();
        
        Bridge storage bridgeConfig = bridges[bridge];
        bridgeConfig.burningLimit = newLimit;
        
        if (resetCounter) {
            bridgeConfig.burnedInPeriod = 0;
            bridgeConfig.lastBurnResetTime = block.timestamp;
        }
        
        emit BridgeLimitsSet(bridgeConfig.mintingLimit, newLimit, bridge);
    }

    /**
     * @dev Get the maximum minting limit for a bridge
     * @param _bridge The bridge address
     * @return _limit The maximum minting limit
     */
    function mintingMaxLimitOf(address _bridge) external view override returns (uint256 _limit) {
        return bridges[_bridge].mintingLimit;
    }
    
    /**
     * @dev Get the current minting limit for a bridge
     * @param _bridge The bridge address
     * @return _limit The current available minting limit
     */
    function mintingCurrentLimitOf(address _bridge) external view override returns (uint256 _limit) {
        Bridge storage bridgeConfig = bridges[_bridge];
        
        // Reset period if needed
        if (block.timestamp >= bridgeConfig.lastMintResetTime + rateLimitPeriod) {
            return bridgeConfig.mintingLimit; // Full limit available after reset
        }
        
        return bridgeConfig.mintingLimit > bridgeConfig.mintedInPeriod 
            ? bridgeConfig.mintingLimit - bridgeConfig.mintedInPeriod 
            : 0;
    }
    
    /**
     * @dev Get the maximum burning limit for a bridge
     * @param _bridge The bridge address
     * @return _limit The maximum burning limit
     */
    function burningMaxLimitOf(address _bridge) external view override returns (uint256 _limit) {
        return bridges[_bridge].burningLimit;
    }
    
    /**
     * @dev Get the current burning limit for a bridge
     * @param _bridge The bridge address
     * @return _limit The current available burning limit
     */
    function burningCurrentLimitOf(address _bridge) external view override returns (uint256 _limit) {
        Bridge storage bridgeConfig = bridges[_bridge];
        
        // Reset period if needed
        if (block.timestamp >= bridgeConfig.lastBurnResetTime + rateLimitPeriod) {
            return bridgeConfig.burningLimit; // Full limit available after reset
        }
        
        return bridgeConfig.burningLimit > bridgeConfig.burnedInPeriod 
            ? bridgeConfig.burningLimit - bridgeConfig.burnedInPeriod 
            : 0;
    }

    /**
     * @dev Check if minting would exceed max supply. Must be implemented by inheriting contract.
     * @param amount The amount to mint
     * @return True if minting would exceed max supply
     */
    function _wouldExceedMaxSupply(uint256 amount) internal view virtual returns (bool);

    /**
     * @dev Internal function to check if an address is allowed to transfer tokens
     * @param from The sending address
     * @param to The receiving address
     * @return True if transfer is allowed
     */
    function _canTransfer(address from, address to) internal view virtual returns (bool) {
        return !(permissioned().isBlacklisted(from) || permissioned().isBlacklisted(to));
    }
    
    /**
     * @dev Public function to check if an address is allowed to transfer tokens
     * @param from The sending address
     * @param to The receiving address
     * @return True if transfer is allowed
     */
    function canTransfer(address from, address to) public view virtual returns (bool) {
        return _canTransfer(from, to);
    }

    /**
     * @dev Check and update the mint limit for a bridge
     * @param bridge The bridge address
     * @param amount The amount to mint
     */
    function _updateMintLimit(address bridge, uint256 amount) internal {
        Bridge storage bridgeConfig = bridges[bridge];
        uint256 currentTime = block.timestamp;
        uint256 periodEnd = bridgeConfig.lastMintResetTime + rateLimitPeriod;
        
        // Reset period if needed
        if (currentTime >= periodEnd) {
            bridgeConfig.mintedInPeriod = amount;
            bridgeConfig.lastMintResetTime = currentTime;
            return;
        }
        
        // Check if transfer would exceed limit
        if (bridgeConfig.mintingLimit == 0 || bridgeConfig.mintedInPeriod + amount > bridgeConfig.mintingLimit) {
            revert IXERC20_NotHighEnoughLimits();
        }
        
        // Update amount minted in this period
        bridgeConfig.mintedInPeriod += amount;
    }
    
    /**
     * @dev Check and update the burn limit for a bridge
     * @param bridge The bridge address
     * @param amount The amount to burn
     */
    function _updateBurnLimit(address bridge, uint256 amount) internal {
        Bridge storage bridgeConfig = bridges[bridge];
        uint256 currentTime = block.timestamp;
        uint256 periodEnd = bridgeConfig.lastBurnResetTime + rateLimitPeriod;
        
        // Reset period if needed
        if (currentTime >= periodEnd) {
            bridgeConfig.burnedInPeriod = amount;
            bridgeConfig.lastBurnResetTime = currentTime;
            return;
        }
        
        // Check if transfer would exceed limit
        if (bridgeConfig.burningLimit == 0 || bridgeConfig.burnedInPeriod + amount > bridgeConfig.burningLimit) {
            revert IXERC20_NotHighEnoughLimits();
        }
        
        // Update amount burned in this period
        bridgeConfig.burnedInPeriod += amount;
    }

    /**
     * @dev Internal function to handle spending allowance
     * @param from The address to spend from
     * @param spender The address spending the tokens
     * @param amount The amount to spend
     */
    function _spendAllowance(address from, address spender, uint256 amount) internal {
        if (from == spender) return;
        
        uint256 currentAllowance = allowance(from, spender);
        if (currentAllowance < amount) revert InsufficientAllowance();
        
        _approve(from, spender, currentAllowance - amount);
    }

    /**
     * @dev Internal implementation of token minting with bridge limits
     * @param to The address to mint tokens to
     * @param amount The amount to mint
     * @param bridge The bridge address requesting the mint
     */
    function _processMint(address to, uint256 amount, address bridge) internal {
        if (amount == 0) revert ZeroAmount();
        
        _updateMintLimit(bridge, amount);
        
        // Check max supply
        if (_wouldExceedMaxSupply(amount)) revert MaxSupplyExceeded();
        
        _mint(to, amount);
        
        emit CrosschainMint(to, amount, bridge);
    }
    
    /**
     * @dev Internal implementation of token burning with bridge limits
     * @param from The address to burn tokens from
     * @param amount The amount to burn
     * @param bridge The bridge address requesting the burn
     */
    function _processBurn(address from, uint256 amount, address bridge) internal {
        if (amount == 0) revert ZeroAmount();
        
        _updateBurnLimit(bridge, amount);
        
        // Handle allowance if caller is not the token owner
        _spendAllowance(from, bridge, amount);
        
        _burn(from, amount);
        
        emit CrosschainBurn(from, amount, bridge);
    }

    /**
     * @dev Mint tokens for a user (IXERC20 implementation)
     * @param _user The user to mint tokens for
     * @param _amount The amount to mint
     */
    function mint(address _user, uint256 _amount) external virtual override nonReentrant onlyApprovedBridge transferAllowed(address(0), _user) {
        _processMint(_user, _amount, msg.sender);
    }

    /**
     * @dev Burn tokens from a user (IXERC20 implementation)
     * @param _user The user to burn tokens from
     * @param _amount The amount to burn
     */
    function burn(address _user, uint256 _amount) external virtual override nonReentrant onlyApprovedBridge transferAllowed(_user, address(0)) {
        _processBurn(_user, _amount, msg.sender);
    }
    
    /**
     * @dev Mint tokens from a cross-chain operation (ERC7802 implementation)
     * @param to The address to mint tokens to
     * @param amount The amount of tokens to mint
     */
    function crosschainMint(address to, uint256 amount) external virtual override nonReentrant onlyApprovedBridge transferAllowed(address(0), to) {
        _processMint(to, amount, msg.sender);
    }
    
    /**
     * @dev Burn tokens for a cross-chain operation (ERC7802 implementation)
     * @param from The address to burn tokens from
     * @param amount The amount of tokens to burn
     */
    function crosschainBurn(address from, uint256 amount) external virtual override nonReentrant onlyApprovedBridge transferAllowed(from, address(0)) {
        _processBurn(from, amount, msg.sender);
    }

    // ========== ERC20 Overrides ==========
    
    /**
     * @dev Override of ERC20 transfer function to check transfer restrictions
     */
    function transfer(address to, uint256 amount) public override(ERC20) transferAllowed(msg.sender, to) returns (bool) {
        return super.transfer(to, amount);
    }
    
    /**
     * @dev Override of ERC20 transferFrom function to check transfer restrictions
     */
    function transferFrom(address from, address to, uint256 amount) public override(ERC20) transferAllowed(from, to) returns (bool) {
        return super.transferFrom(from, to, amount);
    }
    
    // ========== ERC165 Implementation ==========
    
    /**
     * @dev Check if the contract supports an interface
     * @param interfaceId The interface ID to check
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165) returns (bool) {
        return 
            interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(IERC7802).interfaceId ||
            interfaceId == type(IXERC20).interfaceId ||
            interfaceId == type(IERC20).interfaceId ||
            interfaceId == type(ERC20Permit).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
