// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@interfaces/ercs/IERC7802.sol";
import "@interfaces/ercs/IXERC20.sol";
import "@facets/AccessControlFacet.sol";

/**
 * @title BTR Token
 * @dev Cross-chain ERC20 token that implements both ERC7802 and xERC20 interfaces,
 * using any implemented bridge adapter (eg. LayerZero, SuperChain bridge, CCIP, etc.) for cross-chain mint/burn operations.
 * Also implements a freeze feature managed by the MANAGER_ROLE from AccessControlFacet.
 */
contract BTR is ERC20, ERC20Permit, ERC165, ReentrancyGuard, IERC7802, IXERC20 {

    // Custom Errors
    error ZeroAddress();
    error NotAuthorized();
    error AddressFrozen();
    error InvalidRateLimitPeriod();
    error InsufficientAllowance();

    // Custom Events
    event AccessControlUpdated(address indexed prev, address indexed newProxy);
    event RateLimitPeriodUpdated(uint256 newPeriod);
    event Frozen(address indexed account);
    event Unfrozen(address indexed account);

    // Diamond proxy address for access control
    address public accessControl;

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

    // Period for rate limiting
    uint256 public constant MIN_RATE_LIMIT_PERIOD = 1 days;
    uint256 public constant MAX_RATE_LIMIT_PERIOD = 365 days;
    uint256 public rateLimitPeriod = 1 days;

    // Mapping to track approved bridges
    mapping(address => Bridge) public bridges;

    // Freeze mapping
    mapping(address => bool) public frozen;
    
    /**
     * @dev Constructor
     * @param name Token name
     * @param symbol Token symbol
     * @param _accessControl Address of the access control proxy for access control
     */
    constructor(
        string memory name,
        string memory symbol,
        address _accessControl
    ) ERC20(name, symbol) ERC20Permit(name) {
        if (_accessControl == address(0)) revert ZeroAddress();
        accessControl = _accessControl;
    }
    
    /**
     * @dev Function modifier to check if the sender is the access control proxy with ADMIN_ROLE
     */
    modifier onlyAdmin() {
        AccessControlFacet acs = AccessControlFacet(accessControl);
        if (!acs.isAdmin(msg.sender)) revert NotAuthorized();
        _;
    }

    /**
     * @dev Function modifier to check if the sender is the access control proxy with MANAGER_ROLE
     */
    modifier onlyManager() {
        AccessControlFacet acs = AccessControlFacet(accessControl);
        if (!acs.isManager(msg.sender)) revert NotAuthorized();
        _;
    }

    /**
     * @dev Function modifier to check if an address is frozen
     */
    modifier notFrozen(address account) {
        if (frozen[account]) revert AddressFrozen();
        _;
    }

    /**
     * @dev Function modifier to check if a bridge is approved
     */
    modifier onlyApprovedBridge() {
        if (bridges[msg.sender].mintingLimit == 0) revert IXERC20_NotHighEnoughLimits();
        _;
    }

    /**
     * @dev Update the access control address
     * @param diamond The new access control address
     */
    function updateAccessControl(address diamond) external onlyAdmin {
        if (diamond == address(0)) revert ZeroAddress();
        AccessControlFacet acs = AccessControlFacet(diamond);
        // ensure consistency between caller and the new admin
        if (acs.admin() != msg.sender) revert NotAuthorized();
        emit AccessControlUpdated(accessControl, diamond);
        accessControl = diamond;
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
     * @dev Set freeze status for an address
     * @param account The address to update
     */
    function freeze(address account) external onlyManager {
        frozen[account] = true;
        emit Frozen(account);
    }

    function unfreeze(address account) external onlyManager {
        frozen[account] = false;
        emit Unfrozen(account);
    }

    /**
     * @dev Remove approval for a bridge
     * @param bridge The bridge address to remove
     */
    function removeBridge(address bridge) external onlyAdmin {
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

    // ========== IXERC20 Implementation ==========
    
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
        
        return bridgeConfig.mintingLimit - bridgeConfig.mintedInPeriod;
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
        
        return bridgeConfig.burningLimit - bridgeConfig.burnedInPeriod;
    }
    
    /**
     * @dev Mint tokens for a user (IXERC20 implementation)
     * @param _user The user to mint tokens for
     * @param _amount The amount to mint
     */
    function mint(address _user, uint256 _amount) external override onlyApprovedBridge notFrozen(_user) {
        _checkAndUpdateMintLimit(msg.sender, _amount);
        _mint(_user, _amount);
        
        // Emit both standard events for compatibility
        emit CrosschainMint(_user, _amount, msg.sender); // ERC7802
    }

    /**
     * @dev Burn tokens from a user (IXERC20 implementation)
     * @param _user The user to burn tokens from
     * @param _amount The amount to burn
     */
    function burn(address _user, uint256 _amount) external override onlyApprovedBridge notFrozen(_user) {
        _checkAndUpdateBurnLimit(msg.sender, _amount);
        
        // Handle allowance if caller is not the token owner
        if (_user != msg.sender) {
            uint256 currentAllowance = allowance(_user, msg.sender);
            if (currentAllowance < _amount) revert InsufficientAllowance();
            
            // Decrease the allowance
            _approve(_user, msg.sender, currentAllowance - _amount);
        }
        
        _burn(_user, _amount);
        
        emit CrosschainBurn(_user, _amount, msg.sender); // ERC7802
    }
    
    // ========== ERC7802 Implementation ==========
    
    /**
     * @dev Mint tokens from a cross-chain operation (ERC7802 implementation)
     * @param to The address to mint tokens to
     * @param amount The amount of tokens to mint
     */
    function crosschainMint(address to, uint256 amount) external override onlyApprovedBridge notFrozen(to) {
        // Call the IXERC20 mint function to avoid code duplication
        this.mint(to, amount);
    }
    
    /**
     * @dev Burn tokens for a cross-chain operation (ERC7802 implementation)
     * @param from The address to burn tokens from
     * @param amount The amount of tokens to burn
     */
    function crosschainBurn(address from, uint256 amount) external override onlyApprovedBridge notFrozen(from) {
        // Call the IXERC20 burn function to avoid code duplication
        this.burn(from, amount);
    }
    
    // ========== Rate Limit Utilities ==========
    
    /**
     * @dev Check and update the mint limit for a bridge
     * @param bridge The bridge address
     * @param amount The amount to mint
     */
    function _checkAndUpdateMintLimit(address bridge, uint256 amount) internal {
        Bridge storage bridgeConfig = bridges[bridge];
        
        // Reset period if needed
        if (block.timestamp >= bridgeConfig.lastMintResetTime + rateLimitPeriod) {
            bridgeConfig.mintedInPeriod = 0;
            bridgeConfig.lastMintResetTime = block.timestamp;
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
    function _checkAndUpdateBurnLimit(address bridge, uint256 amount) internal {
        Bridge storage bridgeConfig = bridges[bridge];
        
        // Reset period if needed
        if (block.timestamp >= bridgeConfig.lastBurnResetTime + rateLimitPeriod) {
            bridgeConfig.burnedInPeriod = 0;
            bridgeConfig.lastBurnResetTime = block.timestamp;
        }
        
        // Check if transfer would exceed limit
        if (bridgeConfig.burningLimit == 0 || bridgeConfig.burnedInPeriod + amount > bridgeConfig.burningLimit) {
            revert IXERC20_NotHighEnoughLimits();
        }
        
        // Update amount burned in this period
        bridgeConfig.burnedInPeriod += amount;
    }
    
    // ========== ERC20 Overrides ==========
    
    /**
     * @dev Override of ERC20 transfer function to check freeze status
     */
    function transfer(address to, uint256 amount) public override notFrozen(msg.sender) notFrozen(to) returns (bool) {
        return super.transfer(to, amount);
    }
    
    /**
     * @dev Override of ERC20 transferFrom function to check freeze status
     */
    function transferFrom(address from, address to, uint256 amount) public override notFrozen(from) notFrozen(to) returns (bool) {
        return super.transferFrom(from, to, amount);
    }
    
    // ========== ERC165 Implementation ==========
    
    /**
     * @dev Check if the contract supports an interface
     * @param interfaceId The interface ID to check
     */
    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return 
            interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(IERC7802).interfaceId ||
            interfaceId == type(IXERC20).interfaceId ||
            interfaceId == type(IERC20).interfaceId ||
            interfaceId == type(ERC20Permit).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
