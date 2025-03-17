// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/*═══════════════════════════════════════════════════════════════╗
║                          CONSTANTS                             ║
╚═══════════════════════════════════════════════════════════════*/

// Token type bits for rescue operations
enum TokenType {
    NATIVE,      // Native/gas token (eg. ETH, BNB, etc.)
    ERC20,       // ERC20 comliant tokens (including ERC777, ERC3643, ERC4626, ERC7540)
    ERC721,      // NFTs (ERC721)
    ERC1155      // Multi-token standard (ERC1155)
}

// Used for blacklisting/whitelisting addresses
enum AddressType {
    NONE,    // Not blacklisted
    USER,    // User/address blacklisted
    POOL,    // Pool blacklisted
    TOKEN,   // Token blacklisted
    ROUTER   // Router blacklisted
}

enum AccountStatus {
    NONE,
    WHITELISTED,
    BLACKLISTED
}

enum ErrorType {
    CONTRACT,
    FACET,
    ACTION,
    LIBRARY,
    FUNCTION,
    SELECTOR,
    ADDRESS,
    ROLE,
    PROTOCOL,
    ROUTER,
    VAULT,
    TOKEN,
    POOL,
    RANGE,
    TICK,
    DEX,
    ACCESS,
    REENTRANCY,
    MINTER,
    RESCUE,
    ACCEPTANCE,
    ADMIN,
    MANAGER,
    TRANSFER,
    SWAP
}

enum DEX {
    UNISWAP,
    PANCAKESWAP,
    VELODROME,
    AERODROME,
    CAMELOT,
    THENA,
    MAVERICK,
    JOE,
    MERCHANT_MOE,
    SUSHISWAP,
    QUICKSWAP,
    SHADOW,
    KODIAK,
    SWAPX,
    LYNEX,
    ALIEN_BASE,
    AGNI,
    RESERVOIR,
    THRUSTER,
    RAMSES,
    PHARAOH,
    CLEOPATRA,
    NILE,
    NURI,
    BULLA,
    DRAGONSWAP,
    IZISWAP,
    SYNCSWAP,
    STORY_HUNT,
    SPARK_DEX,
    PIPERX,
    RETRO,
    HYPERSWAP,
    BISWAP,
    OCELEX,
    FENIX,
    KOI,
    HERCULES,
    SWAPR,
    EQUALIZER,
    WAGMI,
    KIM,
    STELLASWAP
}

enum FeeType {
    NONE,
    ENTRY,
    EXIT,
    MANAGEMENT,
    PERFORMANCE,
    FLASH
}

/*═══════════════════════════════════════════════════════════════╗
║                    POSITION MANAGEMENT TYPES                   ║
╚═══════════════════════════════════════════════════════════════*/

struct Range {
    bytes32 id;              // keccak256(abi.encodePacked(poolId, positionId))
    bytes32 positionId;      // id of the underlying position
    uint32 vaultId;
    bytes32 poolId;
    uint256 weightBps;       // % weight of the position total
    uint128 liquidity;       // liquidity of the position (LP tokens)
    int24 lowerTick;
    int24 upperTick;
}

struct WithdrawProceeds {
    uint256 burn0;
    uint256 burn1;
    uint256 fee0;
    uint256 fee1;
}

// Detailed DEX pool information
struct PoolInfo {
    bytes32 poolId;
    DEX dex;
    address token0;
    address token1;
    uint32 tickSize;
    uint32 fee;
}

struct Rebalance {
    Range[] ranges;
    address[] swapInputs;
    address[] swapRouters;
    bytes[] swapData;
}

/*═══════════════════════════════════════════════════════════════╗
║                       DIAMOND STORAGE                          ║
╚═══════════════════════════════════════════════════════════════*/

struct FacetAddressAndPosition {
    address facetAddress;
    uint96 functionSelectorPosition; // position in facetFunctionSelectors.functionSelectors array
}

struct FacetFunctionSelectors {
    bytes4[] functionSelectors;
    uint256 facetAddressPosition; // position of facetAddress in facetAddresses array
}

// Diamond Storage
struct Diamond {
    address[] facetAddresses; // array of facet addresses
    mapping(bytes4 => bool) supportedInterfaces; // supported interfaces
    bool cutting; // Reentrancy guard
    mapping(bytes4 => FacetAddressAndPosition) selectorToFacetAndPosition;
    mapping(address => FacetFunctionSelectors) facetFunctionSelectors;
    bytes32[32] __gap; // upgradeable storage padding
}

/*═══════════════════════════════════════════════════════════════╗
║                     ACCESS CONTROL TYPES                       ║
╚═══════════════════════════════════════════════════════════════*/

// Role-related structures
struct RoleData {
    EnumerableSet.AddressSet members;
    bytes32 adminRole;
}

struct PendingAcceptance {
    bytes32 role;
    address replacing;
    uint64 timestamp;
}

struct AccessControl {
    mapping(address => PendingAcceptance) pendingAcceptance;
    mapping(bytes32 => RoleData) roles;
    uint256 grantDelay;       // Delay before a role grant can be accepted
    uint256 acceptWindow;     // Window of time during which a role grant can be accepted
    bytes32[16] __gap;        // upgradeable storage padding
}

/*═══════════════════════════════════════════════════════════════╗
║                     RESTRICTION STORAGE                        ║
╚═══════════════════════════════════════════════════════════════*/

struct Restrictions {
    bool entered;                                   // Reentrancy guard
    bool paused;                                    // Pause state for vault operations
    // Restriction bitmask:
    // 0 = restrictSwapCaller
    // 1 = restrictSwapRouter
    // 2 = restrictSwapInput
    // 3 = restrictSwapOutput
    // 4 = restrictBridgeInput
    // 5 = restrictBridgeOutput
    // 6 = restrictBridgeRouter
    // 7 = approveMax
    // 8 = autoRevoke
    uint256 restrictionMask;                           // Bit flags for various restrictions
    mapping(address => AccountStatus) accountStatus;   // whitelist/blacklist (index 0 is used for protocol level)
    bytes32[16] __gap;                                 // upgradeable storage padding
}

/*═══════════════════════════════════════════════════════════════╗
║                       ORACLES STORAGE                          ║
╚═══════════════════════════════════════════════════════════════*/

struct Oracles {
    uint32 lookback;                         // TWAP interval in seconds for price validation
    uint256 maxDeviation;                    // Maximum allowed deviation between current price and TWAP (in basis points)
    bytes32[32] __gap;                       // upgradeable storage padding
}

/*═══════════════════════════════════════════════════════════════╗
║                       TREASURY STORAGE                         ║
╚═══════════════════════════════════════════════════════════════*/

struct Fees {
    uint16 entry;     // Fee charged when entering the vault (minting)
    uint16 exit;      // Fee charged when exiting the vault (burning)
    uint16 mgmt;      // Ongoing management fee
    uint16 perf;      // Fee on profits
    uint16 flash;     // Fee for flash loan operations
    bytes32[8] __gap;        // upgradeable storage padding
}

struct Treasury {
    address treasury;         // address to receive fees
    Fees defaultFees;         // default protocol fees
    bytes32[32] __gap;        // upgradeable storage padding
}

/*═══════════════════════════════════════════════════════════════╗
║                        VAULT STORAGE                           ║
╚═══════════════════════════════════════════════════════════════*/

struct TimePoints {
    uint64 perfAccruedAt;
    uint64 mgmtAccruedAt;
    uint64 collectedAt;
    bytes32[4] __gap;
}

// Main vault storage structure
struct ALMVault {

    uint32 id;
    // ERC20 properties
    string name;
    string symbol;
    uint8 decimals;
    uint256 totalSupply;
    uint256 maxSupply;           // Maximum supply of vault shares
    mapping(address => uint256) balances; // user balances
    mapping(address => mapping(address => uint256)) allowances; // user allowances

    // Vault positions
    IERC20 token0;
    IERC20 token1;
    bytes32[] ranges;

    // Fee management
    uint64 feesCollectedAt;                      // Last time fees were collected
    uint64 feeAccruedAt;                         // Last time fees were accrued
    Fees fees;                                   // Fee configuration
    mapping(IERC20 => uint256) accruedFees;      // Accrued fees per token
    mapping(IERC20 => uint256) pendingFees;      // Pending fees per token
    TimePoints timePoints;                       // Time points for fees
    uint256 initAmount0;                         // Initial amount for token0 in the vault
    uint256 initAmount1;                         // Initial amount for token1 in the vault
    uint256 initShares;                          // Initial share amount for the first deposit (sets share price)

    // Price protection
    uint32 lookback;                         // TWAP interval in seconds for price validation
    uint256 maxDeviation;                   // Maximum allowed deviation between current price and TWAP (in basis points)
    
    // Restriction state
    bool paused;                                 // Pause state for vault operations
    bool restrictedMint;                         // Uses whitelist if true
    bytes32[16] __gap;                           // upgradeable storage padding
}

// Vault initialization parameters
struct VaultInitParams {
    string name;                 // Vault name
    string symbol;               // Vault symbol
    address token0;              // First token in the pair (lower address)
    address token1;              // Second token in the pair (higher address)
    uint256 initAmount0;         // Initial amount for token0
    uint256 initAmount1;         // Initial amount for token1
    uint256 initShares;          // Initial share amount for the first deposit (sets share price)
}

/*═══════════════════════════════════════════════════════════════╗
║                       REGISTRY STORAGE                         ║
╚═══════════════════════════════════════════════════════════════*/

struct Registry {
    uint32 vaultCount;                          // Number of vaults
    uint32 rangeCount;                          // Number of ranges
    EnumerableSet.UintSet dexs;                 // Set of supported DEX types (using uint for enum)
    mapping(bytes32 => PoolInfo) poolInfo;      // Pool info by poolId
    mapping(uint32 => ALMVault) vaults;         // Vaults by id
    mapping(bytes32 => Range) ranges;           // Protocol-level storage of ranges by rangeId
    mapping(uint8 => address) dexAdapters;      // Dex adapters by dex type
    mapping(IERC20 => address) oracleAdapters;  // Oracle adapters by token address
    mapping(bytes32 => address) bridgeAdapters; // Bridge adapters by chainId
    bytes32[32] __gap;                          // upgradeable storage padding
}

/*═══════════════════════════════════════════════════════════════╗
║                        CORE STORAGE                            ║
╚═══════════════════════════════════════════════════════════════*/

// Core protocol storage
struct CoreStorage {
    // Version control
    uint8 version;                             // protocol version
    AccessControl accessControl;               // Access control storage
    Restrictions restrictions;                 // Restriction storage
    Treasury treasury;                         // Treasury storage
    Registry registry;                         // Registry storage (vaults, pools, dexs)
    Oracles oracles;                           // Oracles storage
    bytes32[64] __gap;                         // upgradeable storage padding
}

/*═══════════════════════════════════════════════════════════════╗
║                       RESCUE STORAGE                           ║
╚═══════════════════════════════════════════════════════════════*/

// Request for rescuing stuck tokens
struct RescueRequest {
    uint64 timestamp;        // When the rescue was requested
    address receiver;        // Address to receive the rescued tokens
    TokenType tokenType;     // Type of token (bitmask of TokenType enum)
    bytes32[] tokens;        // For ERC20: token addresses; For ERC721/ERC1155: token IDs (encoded as bytes32)
}

// Storage for rescue operations
struct Rescue {
    mapping(address => mapping(TokenType => RescueRequest)) rescueRequests;
    uint64 rescueTimelock;   // Time that must pass before a rescue can be executed
    uint64 rescueValidity;   // Time window during which a rescue request is valid
    bytes32[32] __gap;       // upgradeable storage padding
}
