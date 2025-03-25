// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@interfaces/ercs/IERC7802.sol";
import "@interfaces/ercs/IXERC20.sol";

/**
 * @title MockBridge
 * @notice Mock implementation of a cross-chain bridge for testing BTR token
 * @dev Implements functions to test bridge interactions
 */
contract MockBridge {
    // Token interface
    IERC7802 public token;
    IXERC20 public ixerc20Token;
    
    // Events
    event BridgeInitialized(address indexed token);
    event BridgeCrosschainMint(address indexed to, uint256 amount);
    event BridgeCrosschainBurn(address indexed from, uint256 amount);
    event BridgeMint(address indexed to, uint256 amount);
    event BridgeBurn(address indexed from, uint256 amount);
    
    constructor() {}
    
    // Initialize with token address
    function initialize(address _token) external {
        token = IERC7802(_token);
        ixerc20Token = IXERC20(_token);
        emit BridgeInitialized(_token);
    }
    
    // Mint tokens to recipient (IERC7802)
    function bridgeMint(address to, uint256 amount) external {
        token.crosschainMint(to, amount);
        emit BridgeCrosschainMint(to, amount);
    }
    
    // Burn tokens from sender (IERC7802)
    function bridgeBurn(address from, uint256 amount) external {
        token.crosschainBurn(from, amount);
        emit BridgeCrosschainBurn(from, amount);
    }
    
    // Mint tokens to recipient (IXERC20)
    function bridgeMintIXERC20(address to, uint256 amount) external {
        ixerc20Token.mint(to, amount);
        emit BridgeMint(to, amount);
    }
    
    // Burn tokens from sender (IXERC20)
    function bridgeBurnIXERC20(address from, uint256 amount) external {
        ixerc20Token.burn(from, amount);
        emit BridgeBurn(from, amount);
    }
} 