# BTR Supply

## Technical Architecture

BTR Supply implements an alternative approach to Automated Liquidity Management (ALM) using the ERC2535 Diamond pattern and a Uniswap v4-like singleton vault management system based on ERC1155. This document outlines the technical architecture, design decisions, and trade-offs.

### Origins and Inspiration

BTR Supply began as a fork of Arrakis V2, chosen after a comprehensive assessment of existing ALM implementations including:
- Steer Protocol
- Ichi
- Beefy CLM
- Arrakis (V1/V2/V3)
- Gamma
- Skate (formerly Range Protocol)

Arrakis V2 was selected as a foundation due to its:
- Minimalist architecture compared to alternatives
- Multi-range position support
- Comprehensive audit history
- Specialized approach to concentrated liquidity management

While retaining core concepts from Arrakis V2, BTR Supply introduces significant architectural innovations, most notably the transition from individual vault contracts to a singleton diamond pattern implementation.

### Diamond Pattern Implementation (ERC2535)

The system utilizes the Diamond pattern for modularity and upgradeability:

```
BTRDiamond
    ├── DiamondCutFacet        // Contract upgrades
    ├── DiamondLoupeFacet      // Introspection
    ├── AccessControlFacet     // Permission management
    ├── ERC1155Facet     // Multi-vault token operations
    ├── ALMFacet               // Core vault operations
    ├── UniV3Facet             // Uniswap V3 position management
    ├── SwapperFacet           // Exchange routing
    └── Additional facets...   // Specialized functionality
```

The diamond pattern's technical architecture:

1. **Function Selector Routing**: The main diamond contract uses fallback functions to route calls to appropriate facets based on the function selector.
2. **Shared Storage**: All facets access common storage structures via the `BTRStorage` library which provides access to:
   - Diamond administrative data
   - Access control information
   - Protocol-wide settings
   - Vault-specific data

3. **Facet Management**: 
   - Facets are installed/upgraded via the DiamondCutFacet
   - Each facet has a clearly defined responsibility
   - Facets cannot directly call each other (preventing circular dependencies)

#### Storage Organization

```solidity
// Simplified representation of storage organization
struct CoreStorage {
    // Version control
    uint8 version;
    
    // Access control mappings
    mapping(address => AddressType) whitelist;
    mapping(address => AddressType) blacklist;
    
    // Vault registry
    mapping(uint32 => ALMVault) vaults;
    uint32 vaultCount;
    
    // DEX registry
    EnumerableSet.Bytes32Set supportedDEXes;
    mapping(bytes32 => PoolInfo) poolInfo;
}

struct ALMVault {
    uint32 id;
    IERC20Metadata[] tokens;
    uint256 totalSupply;
    mapping(address => uint256) balances;
    // Other vault-specific data...
}
```

### Singleton Vault Architecture: Technical Justification

Traditional DeFi vaults deploy a new contract per vault, resulting in:
- High deployment costs per vault
- Duplicate code across the blockchain
- Upgrades requiring action on multiple contracts

The BTR Supply architecture uses a singleton approach where:

1. A single diamond contract manages all vaults
2. Vaults are identified by a 32-bit ID
3. Tokens use an ERC1155-like model where `(vaultId, address)` identifies a balance

This approach yields gas savings primarily in deployment costs, as only a single contract needs to be deployed regardless of how many vaults are created. New vaults simply require creating a new entry in the vault registry rather than deploying a separate contract.

The trade-off is slightly higher gas costs for token operations due to additional vault ID checks, but this is often outweighed by deployment savings when launching multiple vaults.

### Implementation Details

#### ERC1155-like Token System

Rather than implementing full ERC1155, the system uses a simplified approach:

```solidity
// Balances and transfer implementation
function _transfer(uint32 vaultId, address sender, address recipient, uint256 amount) internal {
    ALMVault storage vs = S.registry().vaults[vaultId];
    
    // Check balance
    if (vs.balances[sender] < amount) revert Errors.Insufficient();
    
    // Update balances
    vs.balances[sender] -= amount;
    vs.balances[recipient] += amount;
    
    emit Events.Transfer(sender, recipient, amount);
}
```

This avoids the overhead of unnecessary ERC1155 functionality while maintaining the core pattern.

#### Cross-DEX Abstraction Layer

The system abstracts DEX interactions:

```solidity
// Simplified representation of position creation
function createPosition(uint32 vaultId, Range memory range) external {
    // Common validation
    if (range.dex == DEX.UNISWAP) {
        _createUniswapPosition(vaultId, range);
    } else if (range.dex == DEX.CAMELOT) {
        _createCamelotPosition(vaultId, range);
    } else {
        revert Errors.UnsupportedDEX();
    }
}
```

Each DEX has its own facet implementing specialized logic for that particular protocol.

### Trade-offs and Considerations

#### Diamond Pattern Considerations

**Advantages:**
- Modular code organization
- Selective upgradeability of components
- No size limit constraints (contracts can exceed 24KB)

**Challenges:**
- More complex storage management
- Potential for storage collisions
- Higher initial gas cost for deployment
- Complexity in ensuring security across facets

#### Singleton Vault Considerations

**Advantages:**
- Significant gas savings for deployment
- Single codebase for all vaults
- Unified upgrade process

**Challenges:**
- Single point of failure risk
- Slightly higher operation costs
- More complex access control requirements
- Potential for cross-vault issues

## Security Considerations

The architecture implements several safeguards:

1. **Nonreentrant Guards**: Prevents reentrancy attacks across facets
2. **Role-Based Access Control**: Granular permissions for different operations
3. **Facet Separation**: Clear separation of concerns between facets
4. **Storage Isolation**: Vaults cannot access each other's data

## Development Approach

The codebase uses Solidity 0.8.28, which provides:
- Built-in overflow/underflow protection
- Custom error types for gas efficiency
- Modern language features

Dependencies include selected OpenZeppelin contracts for standard implementations of security patterns and token standards.

## Setup

```bash
# Install dependencies
./scripts/install_deps.sh

# Compile contracts
forge build
```

## License

MIT 
