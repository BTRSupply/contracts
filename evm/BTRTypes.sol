// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20Metadata} from "@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import {EnumerableSet} from "@openzeppelin/utils/structs/EnumerableSet.sol";

/*═══════════════════════════════════════════════════════════════╗
║                          CONSTANTS                             ║
╚═══════════════════════════════════════════════════════════════*/

// Blacklist types enum
enum AddressType {
    NONE,    // Not blacklisted
    USER,    // User/address blacklisted
    POOL,    // Pool blacklisted
    TOKEN,   // Token blacklisted
    ROUTER   // Router blacklisted
}

enum AccountStatus {
    NONE,
    WHITELIST,
    BLACKLIST
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

/*═══════════════════════════════════════════════════════════════╗
║                          FEE TYPES                             ║
╚═══════════════════════════════════════════════════════════════*/

struct Fees {
    uint16 entry;     // Fee charged when entering the vault (minting)
    uint16 exit;      // Fee charged when exiting the vault (burning)
    uint16 mgmt;      // Ongoing management fee
    uint16 perf;      // Fee on profits
    uint16 flash;     // Fee for flash loan operations
}

/*═══════════════════════════════════════════════════════════════╗
║                    POSITION MANAGEMENT TYPES                   ║
╚═══════════════════════════════════════════════════════════════*/

struct Range {
    bytes32 poolId;
    bytes32 dexType;
    uint256 weightBps; // % weight of the position total
    uint256 positionId; // id of the position
    uint128 liquidity; // liquidity of the position (LP tokens)
    int24 lowerTick;
    int24 upperTick;
}

// Detailed DEX pool information
struct PoolInfo {
    bytes32 poolId;
    bytes32 dexType;
    address token0;
    address token1;
    uint32 tickSize;
    uint32 fee;
}

struct Rebalance {
    Range[] burns;
    Range[] mints;
    SwapPayload[] swaps;
    uint256 minBurn0;
    uint256 minBurn1;
    uint256 minDeposit0;
    uint256 minDeposit1;
}

struct SwapPayload {
    address router;
    bytes swapData;
}

/*═══════════════════════════════════════════════════════════════╗
║                       DIAMOND STORAGE                          ║
╚═══════════════════════════════════════════════════════════════*/

// Diamond Storage for Diamond standard
struct DiamondStorage {
    // maps function selectors to the facets that execute the functions
    // and maps the selectors to their position in the selectors array
    mapping(bytes4 => bytes32) facetAddressAndSelectorPosition;
    // array of function selectors
    bytes4[] selectors;
    // maps facet addresses to their position in the facetAddresses array
    mapping(address => uint256) facetAddressPosition;
    // array of facet addresses
    address[] facetAddresses;
    // supported interfaces
    mapping(bytes4 => bool) supportedInterfaces;
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

/*═══════════════════════════════════════════════════════════════╗
║                      PROTOCOL STORAGE                          ║
╚═══════════════════════════════════════════════════════════════*/

// Core protocol storage
struct ProtocolStorage {
    // Version control
    uint8 version;                             // protocol version

    // Access control
    mapping(address => AccountStatus) accountStatus; // unified status for all addresses
    mapping(address => PendingAcceptance) pendingAcceptance;
    mapping(bytes32 => RoleData) roles;
    uint256 grantDelay;       // Delay before a role grant can be accepted
    uint256 acceptWindow;     // Window of time during which a role grant can be accepted

    // Restriction
    bool entered;                              // Reentrancy guard
    bool paused;                               // Pause state for vault operations
    bool restrictedMint;                       // uses whitelist if true
    // Swapper configuration
    // Restrictions bitmask positions:
    // 0 = restrictCaller
    // 1 = restrictRouter
    // 2 = restrictInput
    // 3 = restrictOutput
    // 4 = approveMax
    // 5 = autoRevoke
    uint256 swapRestrictions;                 // Bit flags for swap restrictions

    // Treasury
    Fees fees;                                 // Protocol level fee configuration
    address treasury;                          // address to receive fees
    mapping(IERC20Metadata => uint256) accruedFees; // accrued fees per token
    mapping(IERC20Metadata => uint256) pendingFees; // pending fees per token

    // Registries
    EnumerableSet.Bytes32Set supportedDEXes;   // Set of supported DEX types
    mapping(bytes32 => PoolInfo) poolInfo;     // Pool info by poolId
    mapping(uint32 => VaultStorage) vaults;    // Vaults by id
    uint32 vaultCount;                         // Number of vaults
}

/*═══════════════════════════════════════════════════════════════╗
║                        VAULT STORAGE                           ║
╚═══════════════════════════════════════════════════════════════*/

// Main vault storage structure
struct VaultStorage {

    uint32 id;

    // ERC4626 vault properties
    string name;
    string symbol;
    uint8 decimals;

    // Vault tokens
    IERC20Metadata asset;     // Primary asset - same as tokens[0] for ERC4626 compatibility
    IERC20Metadata[] tokens;  // Array of tokens managed by the vault (tokens[0], tokens[1], etc.)
    uint256 totalSupply;
    mapping(address => uint256) balances;
    mapping(address => mapping(address => uint256)) allowances;
    mapping(address => AccountStatus) accountStatus; // replaces whitelist/blacklist mappings

    // Vault positions
    Range[] ranges;

    // Pool management

    // Fee management
    Fees fees;                                          // Fee configuration
    mapping(IERC20Metadata => uint256) accruedFees;      // Accrued fees per token
    mapping(IERC20Metadata => uint256) pendingFees;      // Pending fees per token
    uint256[] initialTokenAmounts;                       // Initial amount for each token in the vault
    uint256 initialShareAmount;                          // Initial share amount for the first deposit
    uint256[] managerTokenBalances;                      // Manager balances for each token [token0, token1, ...]

    // Access control
    uint256 maxSupply;                                   // Maximum tokens that can be minted

    // Operational state
    bool paused;                                         // Pause state for vault operations
    bool restrictedMint;                                 // Uses whitelist if true

    // Reentrancy guard
    uint256 reentrancyStatus;                            // 0: not entered, 1: entered
}

// Vault initialization parameters
struct VaultInitParams {
    string name;                 // Vault name
    string symbol;              // Vault symbol
    address token0;              // First token in the pair (lower address)
    address token1;              // Second token in the pair (higher address)
    uint256 initialToken0Amount; // Initial amount for token0
    uint256 initialToken1Amount; // Initial amount for token1
    Fees fees;                   // Fee configuration for the vault
    uint256 maxSupply;           // Maximum supply of vault shares
}

/*═══════════════════════════════════════════════════════════════╗
║                       RESCUE STORAGE                           ║
╚═══════════════════════════════════════════════════════════════*/

// Token type bits for rescue operations
enum TokenType {
    NATIVE,      // 0: Native ETH
    ERC20,       // 1: Standard ERC20 tokens (including ERC777, ERC3643, ERC4626, ERC7540)
    ERC721,      // 2: NFTs (ERC721)
    ERC1155      // 3: Multi-token standard (ERC1155)
}

// Request for rescuing stuck tokens
struct RescueRequest {
    uint64 timestamp;        // When the rescue was requested
    address receiver;        // Address to receive the rescued tokens
    uint8 tokenType;         // Type of token (bitmask of TokenType enum)
    bytes32[] tokens;        // For ERC20: token addresses; For ERC721/ERC1155: token IDs (encoded as bytes32)
}

// Storage for rescue operations
struct RescueStorage {
    mapping(address => mapping(TokenType => RescueRequest)) rescueRequests;
    uint64 rescueTimelock;                             // Delay before rescue can be executed
    uint64 rescueValidity;                             // Time window for executing rescue after unlock
}
