# create3miner

create3miner is a Rust utility for mining salts used to generate Ethereum addresses with specific patterns when using the CREATE3 deployment standard (EIP3171).

## Features

- Mine salts for addresses with specific patterns
- Works with deployer-specific salt calculation
- Supports complex pattern matching:
  - Simple hex prefixes (`000000`)
  - Leading and trailing patterns (`000...000`)
  - OR conditions (`(A|B|CCC)`)
  - Combinations of the above
- Multi-threaded for maximum performance
- Real-time statistics and progress reporting

## Prerequisites

- Rust and Cargo installed
- The following Rust dependencies (specified in Cargo.toml):
  - clap
  - ethers
  - hex
  - rand
  - rayon
  - num_cpus
  - regex

## Building

```bash
# Navigate to the directory containing the Cargo.toml
cd tools/create3miner

# Build the project in release mode for maximum performance
cargo build --release
```

## Usage

```bash
# Run the miner with required parameters
cargo run --release -- --pattern <PATTERN> --salt <BASE_SALT> --deployer <DEPLOYER_ADDRESS> [OPTIONS]
```

### Command Line Arguments

- `-p, --pattern <PATTERN>`: Pattern to match (see pattern syntax below)
- `-s, --salt <STRING>`: Base salt string to use (will be hashed)
- `-d, --deployer <ADDRESS>`: Deployer address (with 0x prefix)
- `-t, --threads <NUMBER>`: Number of threads to use (default: number of logical CPUs)
- `-l, --limit <NUMBER>`: Stop after finding this many matching salts (default: 1)

## Pattern Syntax

The salt miner supports several pattern matching formats:

### Simple Hex Prefix

Match addresses that start with specific hex digits:

```bash
# Find addresses starting with "000000"
cargo run --release -- -p 000000 -s "project.v1" -d 0x1234...5678
```

### Leading and Trailing Patterns

Match addresses with specific leading and/or trailing hex digits, separated by `...`:

```bash
# Find addresses with 3 leading zeros and 3 trailing zeros
cargo run --release -- -p "000...000" -s "project.v1" -d 0x1234...5678

# Find addresses with just leading zeros
cargo run --release -- -p "000..." -s "project.v1" -d 0x1234...5678

# Find addresses with just trailing zeros
cargo run --release -- -p "...000" -s "project.v1" -d 0x1234...5678
```

### OR Conditions

Match addresses where leading or trailing parts match one of several options:

```bash
# Find addresses starting with A or B or CCC
cargo run --release -- -p "(A|B|CCC)..." -s "project.v1" -d 0x1234...5678

# Find addresses ending with A or B or CCC
cargo run --release -- -p "...(A|B|CCC)" -s "project.v1" -d 0x1234...5678
```

### Complex Patterns

Combine leading and trailing patterns with OR conditions:

```bash
# Find addresses starting with 0, 1, 2, or 3 and ending with 0000 or 0001
cargo run --release -- -p "(0|1|2|3)...(0000|0001)" -s "project.v1" -d 0x1234...5678
```

## How It Works

The salt miner:
1. Takes your pattern and parses it into the appropriate matching strategy
2. Systematically tries variations of the base salt
3. For each candidate salt, it:
   - Computes the deployer-specific salt by hashing the salt with the deployer address (such as `DeterministicDeployer.sol`)
   - Calculates the CREATE3 address that would result from this salt
   - Checks if the address matches your pattern
4. When a match is found, it reports the salt and resulting address

## Using the Mined Salts

Once you have found a suitable salt, you can use it with your `DeterministicDeployer.sol` contract:

```solidity
// Example with a mined salt (replace with your actual mined salt)
bytes32 salt = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;

// Deploy your contract with the mined salt
address deployedContract = deterministicDeployer.deploy(
    creationCode,
    salt
);
```

## Performance Considerations

- Mining salts can be computationally intensive
- Using more threads will generally increase performance on multi-core systems
- The difficulty increases exponentially with the length of the pattern
- Complex patterns with OR conditions may be faster than simple patterns if they match more addresses
- Leading zeros are typically harder to find than trailing zeros
