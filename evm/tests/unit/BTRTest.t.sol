// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../BaseTest.t.sol";
import {BTR} from "@/BTR.sol";
import {TreasuryFacet} from "@facets/TreasuryFacet.sol";
import {AccessControlFacet} from "@facets/AccessControlFacet.sol";
import {LibAccessControl} from "@libraries/LibAccessControl.sol";
import {IDiamond} from "@interfaces/IDiamond.sol";
import {IDiamondCut} from "@interfaces/IDiamond.sol";
import {IERC7802} from "@interfaces/ercs/IERC7802.sol";
import {IXERC20} from "@interfaces/ercs/IXERC20.sol";
import {IERC20} from "@interfaces/ercs/IERC20.sol";
import {ManagementFacet} from "@facets/ManagementFacet.sol";
import {ERC20Bridgeable} from "@abstract/ERC20Bridgeable.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

// Define errors from ERC20Permit.sol for testing
error ERC2612ExpiredSignature(uint256 deadline);
error ERC2612InvalidSigner(address signer, address owner);

/**
 * @title BTRTest
 * @notice Comprehensive test for the BTR token
 */
contract BTRTest is BaseTest {
    // Token parameters
    string constant NAME = "BTR Token";
    string constant SYMBOL = "BTR";
    uint256 constant MAX_SUPPLY = 1_000_000_000 * 10**18; // 1 billion tokens with 18 decimals
    uint256 constant GENESIS_AMOUNT = 500_000_000 * 10**18; // 500 million tokens for genesis
    
    // Test parameters
    uint256 constant BRIDGE_MINT_LIMIT = 100_000_000 * 10**18; // 100 million
    uint256 constant BRIDGE_BURN_LIMIT = 100_000_000 * 10**18; // 100 million
    
    // Contract instance
    BTR public btr;
    
    // Test addresses
    address public bridge;
    address public user1;
    address public user2;
    address public blacklistedUser;
    address public spender;
    
    // Private keys for signature testing
    uint256 private user1PrivateKey;
    
    // EIP-2612 Permit constants
    bytes32 public constant PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    
    // Events for testing
    event BridgeLimitsSet(uint256 indexed mintingLimit, uint256 indexed burningLimit, address indexed bridge);
    event CrosschainMint(address indexed to, uint256 indexed amount, address indexed bridge);
    event CrosschainBurn(address indexed from, uint256 indexed amount, address indexed bridge);
    event RateLimitPeriodUpdated(uint256 newPeriod);
    event GenesisMint(address indexed treasury, uint256 amount);
    event MaxSupplyUpdated(uint256 newMaxSupply);
    
    /**
     * @notice Setup for BTR token tests
     */
    function setUp() public override {
        // Setup the base test (diamond, admin, manager, treasury)
        super.setUp();
        
        // Set up additional test addresses
        bridge = address(0xB812);
        user1 = vm.addr(1); // Using deterministic address derived from private key 1
        user1PrivateKey = 1; // Private key for signing permit
        user2 = address(0xCAFE);
        blacklistedUser = address(0xDEAD);
        spender = address(0xBEEF);
        
        // Deploy BTR token
        btr = new BTR(NAME, SYMBOL, address(diamond), MAX_SUPPLY);
        
        // Mint genesis tokens to treasury to have tokens available for tests
        vm.prank(admin);
        btr.mintGenesis(GENESIS_AMOUNT);
    }
    
    /**
     * @notice Test initial token setup
     */
    function testInitialSetup() public {
        assertEq(btr.name(), NAME);
        assertEq(btr.symbol(), SYMBOL);
        assertEq(btr.maxSupply(), MAX_SUPPLY);
        assertEq(btr.totalSupply(), 0);
        assertEq(btr.genesisMinted(), false);
        assertEq(btr.treasury(), treasury);
        
        // Check ERC165 interface support
        assertTrue(btr.supportsInterface(type(IERC165).interfaceId));
        assertTrue(btr.supportsInterface(type(IERC7802).interfaceId));
        assertTrue(btr.supportsInterface(type(IXERC20).interfaceId));
        // IERC20 doesn't have an interfaceId as it's not ERC165-compliant
        // Skip the IERC20 interface check
    }
    
    /**
     * @notice Test genesis minting
     */
    function testGenesisMint() public {
        // Only admin can mint genesis
        vm.prank(user1);
        vm.expectRevert();
        btr.mintGenesis(GENESIS_AMOUNT);
        
        // Expect GenesisMint event
        vm.expectEmit(true, true, true, true);
        emit GenesisMint(treasury, GENESIS_AMOUNT);
        
        // Admin can mint genesis
        vm.prank(admin);
        btr.mintGenesis(GENESIS_AMOUNT);
        
        // Verify genesis minted
        assertEq(btr.genesisMinted(), true);
        assertEq(btr.totalSupply(), GENESIS_AMOUNT);
        assertEq(btr.balanceOf(treasury), GENESIS_AMOUNT);
        
        // Cannot mint genesis twice
        vm.prank(admin);
        vm.expectRevert(BTR.GenesisAlreadyMinted.selector);
        btr.mintGenesis(GENESIS_AMOUNT);
    }
    
    /**
     * @notice Test genesis mint with zero amount
     */
    function testGenesisMintZeroAmount() public {
        vm.prank(admin);
        vm.expectRevert(BTR.InvalidAmount.selector);
        btr.mintGenesis(0);
    }
    
    /**
     * @notice Test exceeding max supply in genesis mint
     */
    function testGenesisMintExceedsMaxSupply() public {
        vm.prank(admin);
        vm.expectRevert(ERC20Bridgeable.MaxSupplyExceeded.selector);
        btr.mintGenesis(MAX_SUPPLY + 1);
    }
    
    /**
     * @notice Test treasury minting
     */
    function testMintToTreasury() public {
        uint256 mintAmount = 100_000_000 * 10**18;
        
        // Only admin can mint to treasury
        vm.prank(user1);
        vm.expectRevert();
        btr.mintToTreasury(mintAmount);
        
        // Admin can mint to treasury
        vm.prank(admin);
        btr.mintToTreasury(mintAmount);
        
        // Verify mint
        assertEq(btr.totalSupply(), mintAmount);
        assertEq(btr.balanceOf(treasury), mintAmount);
        
        // Cannot exceed max supply
        vm.prank(admin);
        vm.expectRevert(ERC20Bridgeable.MaxSupplyExceeded.selector);
        btr.mintToTreasury(MAX_SUPPLY);
    }
    
    /**
     * @notice Test treasury mint with zero amount
     */
    function testMintToTreasuryZeroAmount() public {
        vm.prank(admin);
        vm.expectRevert(BTR.InvalidAmount.selector);
        btr.mintToTreasury(0);
    }
    
    /**
     * @notice Test updating max supply
     */
    function testSetMaxSupply() public {
        uint256 newMaxSupply = MAX_SUPPLY * 2;
        
        // Only admin can update max supply
        vm.prank(user1);
        vm.expectRevert();
        btr.setMaxSupply(newMaxSupply);
        
        // Expect MaxSupplyUpdated event
        vm.expectEmit(true, true, true, true);
        emit MaxSupplyUpdated(newMaxSupply);
        
        // Admin can update max supply
        vm.prank(admin);
        btr.setMaxSupply(newMaxSupply);
        
        // Verify update
        assertEq(btr.maxSupply(), newMaxSupply);
        
        // Cannot set max supply to 0
        vm.prank(admin);
        vm.expectRevert(BTR.InvalidMaxSupply.selector);
        btr.setMaxSupply(0);
        
        // Cannot set max supply below total supply
        vm.prank(admin);
        btr.mintToTreasury(10**18);
        
        vm.prank(admin);
        vm.expectRevert(BTR.InvalidMaxSupply.selector);
        btr.setMaxSupply(10**18 - 1);
    }
    
    /**
     * @notice Test bridge setup and limits
     */
    function testBridgeLimits() public {
        // Only admin can set limits
        vm.prank(user1);
        vm.expectRevert();
        btr.setLimits(bridge, BRIDGE_MINT_LIMIT, BRIDGE_BURN_LIMIT);
        
        // Expect BridgeLimitsSet event
        vm.expectEmit(true, true, true, true);
        emit BridgeLimitsSet(BRIDGE_MINT_LIMIT, BRIDGE_BURN_LIMIT, bridge);
        
        // Admin can set limits
        vm.prank(admin);
        btr.setLimits(bridge, BRIDGE_MINT_LIMIT, BRIDGE_BURN_LIMIT);
        
        // Verify limits
        assertEq(btr.mintingMaxLimitOf(bridge), BRIDGE_MINT_LIMIT);
        assertEq(btr.mintingCurrentLimitOf(bridge), BRIDGE_MINT_LIMIT);
        assertEq(btr.burningMaxLimitOf(bridge), BRIDGE_BURN_LIMIT);
        assertEq(btr.burningCurrentLimitOf(bridge), BRIDGE_BURN_LIMIT);
    }
    
    /**
     * @notice Test bridge limit updates
     */
    function testUpdateBridgeLimits() public {
        uint256 newMintLimit = BRIDGE_MINT_LIMIT * 2;
        uint256 newBurnLimit = BRIDGE_BURN_LIMIT * 2;
        
        // Setup bridge
        vm.prank(admin);
        btr.setLimits(bridge, BRIDGE_MINT_LIMIT, BRIDGE_BURN_LIMIT);
        
        // Only admin can update limits
        vm.prank(user1);
        vm.expectRevert();
        btr.updateMintLimit(bridge, newMintLimit, true);
        
        // Admin can update mint limit
        vm.prank(admin);
        btr.updateMintLimit(bridge, newMintLimit, true);
        
        // Admin can update burn limit
        vm.prank(admin);
        btr.updateBurnLimit(bridge, newBurnLimit, true);
        
        // Verify updates
        assertEq(btr.mintingMaxLimitOf(bridge), newMintLimit);
        assertEq(btr.burningMaxLimitOf(bridge), newBurnLimit);
        
        // Test counter reset flag (false)
        uint256 mintAmount = 10**18;
        vm.prank(bridge);
        btr.crosschainMint(user1, mintAmount);
        
        vm.prank(admin);
        btr.updateMintLimit(bridge, newMintLimit / 2, false);
        
        // Counter should not reset
        assertEq(btr.mintingCurrentLimitOf(bridge), newMintLimit / 2 - mintAmount);
    }
    
    /**
     * @notice Test removing a bridge
     */
    function testRemoveBridge() public {
        // Setup bridge
        vm.prank(admin);
        btr.setLimits(bridge, BRIDGE_MINT_LIMIT, BRIDGE_BURN_LIMIT);
        
        // Only admin can remove bridge
        vm.prank(user1);
        vm.expectRevert();
        btr.removeBridge(bridge);
        
        // Admin can remove bridge
        vm.prank(admin);
        btr.removeBridge(bridge);
        
        // Verify bridge removed
        assertEq(btr.mintingMaxLimitOf(bridge), 0);
        assertEq(btr.burningMaxLimitOf(bridge), 0);
        
        // Cannot use removed bridge
        vm.prank(bridge);
        vm.expectRevert();
        btr.mint(user1, 1);
    }
    
    /**
     * @notice Test zero address bridge
     */
    function testZeroAddressBridge() public {
        vm.prank(admin);
        vm.expectRevert();
        btr.setLimits(address(0), BRIDGE_MINT_LIMIT, BRIDGE_BURN_LIMIT);
        
        vm.prank(admin);
        vm.expectRevert();
        btr.removeBridge(address(0));
    }
    
    /**
     * @notice Test non-existent bridge
     */
    function testNonExistentBridge() public {
        vm.prank(admin);
        vm.expectRevert();
        btr.removeBridge(bridge);
    }
    
    /**
     * @notice Test cross-chain minting via bridge
     */
    function testCrosschainMint() public {
        uint256 mintAmount = 10**18;
        
        // Setup bridge
        vm.prank(admin);
        btr.setLimits(bridge, BRIDGE_MINT_LIMIT, BRIDGE_BURN_LIMIT);
        
        // Only bridge can mint
        vm.prank(user1);
        vm.expectRevert();
        btr.crosschainMint(user1, mintAmount);
        
        // Expect CrosschainMint event
        vm.expectEmit(true, true, true, true);
        emit CrosschainMint(user1, mintAmount, bridge);
        
        // Bridge can mint to user
        vm.prank(bridge);
        btr.crosschainMint(user1, mintAmount);
        
        // Verify mint
        assertEq(btr.totalSupply(), mintAmount);
        assertEq(btr.balanceOf(user1), mintAmount);
        
        // Verify limit usage
        assertEq(btr.mintingCurrentLimitOf(bridge), BRIDGE_MINT_LIMIT - mintAmount);
    }
    
    /**
     * @notice Test cross-chain burning via bridge
     */
    function testCrosschainBurn() public {
        uint256 mintAmount = 10**18;
        
        // Setup bridge and mint tokens
        vm.prank(admin);
        btr.setLimits(bridge, BRIDGE_MINT_LIMIT, BRIDGE_BURN_LIMIT);
        
        vm.prank(bridge);
        btr.crosschainMint(user1, mintAmount);
        
        // Only bridge can burn
        vm.prank(user1);
        vm.expectRevert();
        btr.crosschainBurn(user1, mintAmount);
        
        // User must approve bridge to burn their tokens
        vm.prank(user1);
        btr.approve(bridge, mintAmount);
        
        // Expect CrosschainBurn event
        vm.expectEmit(true, true, true, true);
        emit CrosschainBurn(user1, mintAmount, bridge);
        
        // Bridge can burn from user
        vm.prank(bridge);
        btr.crosschainBurn(user1, mintAmount);
        
        // Verify burn
        assertEq(btr.totalSupply(), 0);
        assertEq(btr.balanceOf(user1), 0);
        
        // Verify limit usage
        assertEq(btr.burningCurrentLimitOf(bridge), BRIDGE_BURN_LIMIT - mintAmount);
    }
    
    /**
     * @notice Test standard IXERC20 mint function
     */
    function testIXERC20Mint() public {
        uint256 mintAmount = 10**18;
        
        // Setup bridge
        vm.prank(admin);
        btr.setLimits(bridge, BRIDGE_MINT_LIMIT, BRIDGE_BURN_LIMIT);
        
        // Bridge can mint to user
        vm.prank(bridge);
        btr.mint(user1, mintAmount);
        
        // Verify mint
        assertEq(btr.totalSupply(), mintAmount);
        assertEq(btr.balanceOf(user1), mintAmount);
    }
    
    /**
     * @notice Test standard IXERC20 burn function
     */
    function testIXERC20Burn() public {
        uint256 mintAmount = 10**18;
        
        // Setup bridge and mint tokens
        vm.prank(admin);
        btr.setLimits(bridge, BRIDGE_MINT_LIMIT, BRIDGE_BURN_LIMIT);
        
        vm.prank(bridge);
        btr.mint(user1, mintAmount);
        
        // User must approve bridge to burn their tokens
        vm.prank(user1);
        btr.approve(bridge, mintAmount);
        
        // Bridge can burn from user
        vm.prank(bridge);
        btr.burn(user1, mintAmount);
        
        // Verify burn
        assertEq(btr.totalSupply(), 0);
        assertEq(btr.balanceOf(user1), 0);
    }
    
    /**
     * @notice Test rate limit period updates
     */
    function testRateLimitPeriod() public {
        uint256 newPeriod = 7 days;
        
        // Only admin can update rate limit period
        vm.prank(user1);
        vm.expectRevert();
        btr.setRateLimitPeriod(newPeriod);
        
        // Expect RateLimitPeriodUpdated event
        vm.expectEmit(true, true, true, true);
        emit RateLimitPeriodUpdated(newPeriod);
        
        // Admin can update rate limit period
        vm.prank(admin);
        btr.setRateLimitPeriod(newPeriod);
        
        // Verify update
        assertEq(btr.rateLimitPeriod(), newPeriod);
        
        // Test invalid period (too short)
        vm.prank(admin);
        vm.expectRevert();
        btr.setRateLimitPeriod(12 hours);
        
        // Test invalid period (too long)
        vm.prank(admin);
        vm.expectRevert();
        btr.setRateLimitPeriod(366 days);
    }
    
    /**
     * @notice Test rate limit reset period
     */
    function testRateLimitReset() public {
        uint256 mintAmount = 10**18;
        
        // Setup bridge
        vm.prank(admin);
        btr.setLimits(bridge, mintAmount, mintAmount);
        
        // Mint full limit
        vm.prank(bridge);
        btr.mint(user1, mintAmount);
        
        // Cannot mint more in same period
        vm.prank(bridge);
        vm.expectRevert();
        btr.mint(user1, 1);
        
        // Advance time by rate limit period
        vm.warp(block.timestamp + btr.rateLimitPeriod() + 1);
        
        // Can mint again after period reset
        vm.prank(bridge);
        btr.mint(user1, mintAmount);
        
        // Verify mint
        assertEq(btr.balanceOf(user1), mintAmount * 2);
    }
    
    /**
     * @notice Test blacklisted user restrictions
     */
    function testBlacklistedUserRestrictions() public {
        uint256 mintAmount = 10**18;
        
        // Setup bridge and mint tokens
        vm.prank(admin);
        btr.setLimits(bridge, BRIDGE_MINT_LIMIT, BRIDGE_BURN_LIMIT);
        
        vm.prank(bridge);
        btr.mint(user1, mintAmount);
        
        // Blacklist user1
        vm.prank(admin);
        ManagementFacet(diamond).addToBlacklist(user1);
        
        // Cannot transfer from blacklisted user
        vm.prank(user1);
        vm.expectRevert();
        btr.transfer(user2, mintAmount);
        
        // Cannot transfer to blacklisted user
        vm.prank(bridge);
        vm.expectRevert();
        btr.mint(user1, mintAmount);
        
        // Remove from blacklist
        vm.prank(admin);
        ManagementFacet(diamond).removeFromList(user1);
        
        // Can transfer after removal from blacklist
        vm.prank(user1);
        btr.transfer(user2, mintAmount);
        
        // Verify transfer
        assertEq(btr.balanceOf(user1), 0);
        assertEq(btr.balanceOf(user2), mintAmount);
    }
    
    /**
     * @notice Test ERC20 functionality
     */
    function testERC20Functionality() public {
        uint256 mintAmount = 10**18;
        
        // Mint tokens to user1
        vm.prank(admin);
        btr.setLimits(bridge, BRIDGE_MINT_LIMIT, BRIDGE_BURN_LIMIT);
        
        vm.prank(bridge);
        btr.mint(user1, mintAmount);
        
        // Test transfer
        vm.prank(user1);
        btr.transfer(user2, mintAmount / 2);
        assertEq(btr.balanceOf(user1), mintAmount / 2);
        assertEq(btr.balanceOf(user2), mintAmount / 2);
        
        // Test approve and transferFrom
        vm.prank(user1);
        btr.approve(user2, mintAmount / 2);
        
        vm.prank(user2);
        btr.transferFrom(user1, user2, mintAmount / 2);
        
        assertEq(btr.balanceOf(user1), 0);
        assertEq(btr.balanceOf(user2), mintAmount);
    }
    
    /**
     * @notice Test zero token transfers
     */
    function testZeroAmountTransfers() public {
        // Mint some tokens
        vm.prank(admin);
        btr.mintToTreasury(10**18);
        
        // Zero amount transfer
        vm.prank(treasury);
        btr.transfer(user1, 0);
        
        // Zero amount approve and transferFrom
        vm.prank(treasury);
        btr.approve(user1, 0);
        
        vm.prank(user1);
        btr.transferFrom(treasury, user1, 0);
    }
    
    /**
     * @notice Test that the token supports ERC20Permit interface
     */
    function testERC20PermitInterface() public view {
        assertTrue(btr.supportsInterface(type(IERC20Permit).interfaceId));
    }
    
    /**
     * @notice Test basic ERC20Permit functionality
     */
    function testPermitBasic() public {
        uint256 permitAmount = 10**18;
        
        // Transfer tokens from treasury to user1
        vm.prank(treasury);
        btr.transfer(user1, permitAmount * 2);
        
        // Verify user1 balance
        assertEq(btr.balanceOf(user1), permitAmount * 2);
        
        // Set deadline to 1 day in the future
        uint256 deadline = block.timestamp + 1 days;
        
        // Verify initial state
        assertEq(btr.allowance(user1, spender), 0);
        assertEq(btr.nonces(user1), 0);
        
        // Get domain separator from the contract
        bytes32 domainSeparator = btr.DOMAIN_SEPARATOR();
        
        // Generate the permit signature
        (uint8 v, bytes32 r, bytes32 s) = _createPermitSignature(
            domainSeparator,
            user1,
            spender,
            permitAmount,
            0, // nonce
            deadline,
            user1PrivateKey
        );
        
        // Call permit function
        vm.prank(spender); // Anyone can submit the permit
        btr.permit(user1, spender, permitAmount, deadline, v, r, s);
        
        // Verify the allowance is set and nonce increased
        assertEq(btr.allowance(user1, spender), permitAmount);
        assertEq(btr.nonces(user1), 1);
        
        // Use the allowance with transferFrom
        vm.prank(spender);
        btr.transferFrom(user1, spender, permitAmount);
        
        // Verify balance changes
        assertEq(btr.balanceOf(user1), permitAmount);
        assertEq(btr.balanceOf(spender), permitAmount);
        
        // Verify allowance was used
        assertEq(btr.allowance(user1, spender), 0);
    }
    
    /**
     * @notice Test permit with expired deadline
     */
    function testPermitExpiredDeadline() public {
        uint256 permitAmount = 10**18;
        uint256 deadline = block.timestamp - 1; // Expired deadline
        
        // Get domain separator from the contract
        bytes32 domainSeparator = btr.DOMAIN_SEPARATOR();
        
        // Generate the permit signature
        (uint8 v, bytes32 r, bytes32 s) = _createPermitSignature(
            domainSeparator,
            user1,
            spender,
            permitAmount,
            0, // nonce
            deadline,
            user1PrivateKey
        );
        
        // Call permit function with expired deadline should revert with specific error
        vm.expectRevert(abi.encodeWithSelector(ERC2612ExpiredSignature.selector, deadline));
        vm.prank(spender);
        btr.permit(user1, spender, permitAmount, deadline, v, r, s);
    }
    
    /**
     * @notice Test permit with invalid signature
     */
    function testPermitInvalidSignature() public {
        uint256 permitAmount = 10**18;
        uint256 deadline = block.timestamp + 1 days;
        
        // Get domain separator from the contract
        bytes32 domainSeparator = btr.DOMAIN_SEPARATOR();
        
        // Generate valid signature first
        (uint8 v, bytes32 r, bytes32 s) = _createPermitSignature(
            domainSeparator,
            user1,
            spender,
            permitAmount,
            0, // nonce
            deadline,
            user1PrivateKey
        );
        
        // Modified amount for invalid signature test
        uint256 modifiedAmount = permitAmount + 1;
        
        // Cannot predict exact signer address in the error, so use a generic expectRevert
        vm.expectRevert();
        vm.prank(spender);
        btr.permit(user1, spender, modifiedAmount, deadline, v, r, s); // Wrong amount
    }
    
    /**
     * @notice Test permit with replay protection (nonce)
     */
    function testPermitReplayProtection() public {
        uint256 permitAmount = 10**18;
        uint256 deadline = block.timestamp + 1 days;
        
        // Transfer tokens from treasury to user1
        vm.prank(treasury);
        btr.transfer(user1, permitAmount * 2);
        
        // Verify user1 balance
        assertEq(btr.balanceOf(user1), permitAmount * 2);
        
        // Get domain separator from the contract
        bytes32 domainSeparator = btr.DOMAIN_SEPARATOR();
        
        // Generate the permit signature
        (uint8 v, bytes32 r, bytes32 s) = _createPermitSignature(
            domainSeparator,
            user1,
            spender,
            permitAmount,
            0, // nonce
            deadline,
            user1PrivateKey
        );
        
        // Call permit function
        vm.prank(spender);
        btr.permit(user1, spender, permitAmount, deadline, v, r, s);
        
        // Verify the nonce increased
        assertEq(btr.nonces(user1), 1);
        
        // Trying to use the same signature again should fail
        vm.expectRevert();
        vm.prank(spender);
        btr.permit(user1, spender, permitAmount, deadline, v, r, s);
        
        // Generate signature with correct nonce
        (v, r, s) = _createPermitSignature(
            domainSeparator,
            user1,
            spender,
            permitAmount,
            1, // Current nonce
            deadline,
            user1PrivateKey
        );
        
        // Using signature with correct nonce should succeed
        vm.prank(spender);
        btr.permit(user1, spender, permitAmount, deadline, v, r, s);
        
        // Verify nonce increased again
        assertEq(btr.nonces(user1), 2);
    }
    
    /**
     * @notice Test permit with blacklisted user
     */
    function testPermitWithBlacklist() public {
        uint256 permitAmount = 10**18;
        uint256 deadline = block.timestamp + 1 days;
        
        // Transfer tokens from treasury to user1
        vm.prank(treasury);
        btr.transfer(user1, permitAmount);
        
        // Verify user1 balance
        assertEq(btr.balanceOf(user1), permitAmount);
        
        // Get domain separator from the contract
        bytes32 domainSeparator = btr.DOMAIN_SEPARATOR();
        
        // Generate permit signature with correct nonce
        (uint8 v, bytes32 r, bytes32 s) = _createPermitSignature(
            domainSeparator,
            user1,
            spender,
            permitAmount,
            0,
            deadline,
            user1PrivateKey
        );
        
        // Blacklist user1
        vm.prank(admin);
        ManagementFacet(diamond).addToBlacklist(user1);
        
        // Permit should work since it only sets allowance
        vm.prank(spender);
        btr.permit(user1, spender, permitAmount, deadline, v, r, s);
        
        // But transferFrom should be blocked
        vm.prank(spender);
        vm.expectRevert();
        btr.transferFrom(user1, spender, permitAmount);
        
        // Remove from blacklist
        vm.prank(admin);
        ManagementFacet(diamond).removeFromList(user1);
        
        // Now transferFrom should work
        vm.prank(spender);
        btr.transferFrom(user1, spender, permitAmount);
        
        // Verify balances
        assertEq(btr.balanceOf(user1), 0);
        assertEq(btr.balanceOf(spender), permitAmount);
    }
    
    /**
     * @notice Helper function to create permit signature
     */
    function _createPermitSignature(
        bytes32 domainSeparator,
        address owner,
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline,
        uint256 privateKey
    ) internal pure returns (uint8 v, bytes32 r, bytes32 s) {
        bytes32 structHash = keccak256(
            abi.encode(
                PERMIT_TYPEHASH,
                owner,
                spender,
                value,
                nonce,
                deadline
            )
        );
        
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                structHash
            )
        );
        
        (v, r, s) = vm.sign(privateKey, digest);
    }
} 