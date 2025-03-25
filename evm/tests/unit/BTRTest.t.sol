// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {BTR} from "@/BTR.sol";
import {MockDiamond} from "../mocks/MockDiamond.sol";
import {MockBridge} from "../mocks/MockBridge.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ERC2612Test} from "@openzeppelin/contracts/mocks/ERC2612Test.sol";

/**
 * @title BTRTest
 * @notice Comprehensive unit test for the BTR token
 * @dev Tests all functionality of the BTR token including ERC20, bridging, and role-based access
 */
contract BTRTest is Test {
    // Token parameters
    string constant NAME = "BTR Token";
    string constant SYMBOL = "BTR";
    uint256 constant MAX_SUPPLY = 1_000_000_000 * 10**18; // 1 billion tokens with 18 decimals
    uint256 constant GENESIS_MINT_AMOUNT = 500_000_000 * 10**18; // 500 million tokens
    
    // Contract instances
    BTR public btr;
    MockDiamond public diamond;
    MockBridge public bridge;
    
    // Test addresses
    address public admin;
    address public treasury;
    address public user1;
    address public user2;
    address public user3;
    address public blacklisted;
    
    // Events to test
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event MaxSupplyUpdated(uint256 newMaxSupply);
    event GenesisMint(address indexed treasury, uint256 amount);
    event CrosschainMint(address indexed to, uint256 amount, address indexed bridge);
    event CrosschainBurn(address indexed from, uint256 amount, address indexed bridge);
    event BridgeLimitsSet(uint256 mintingLimit, uint256 burningLimit, address indexed bridge);
    event RateLimitPeriodUpdated(uint256 newPeriod);
    event TransferBlocked(address indexed from, address indexed to, uint256 value);
    
    function setUp() public {
        // Set up addresses
        admin = address(this);
        treasury = address(0x5678);
        user1 = address(0x1111);
        user2 = address(0x2222);
        user3 = address(0x3333);
        blacklisted = address(0xBAD);
        
        // Deploy mock diamond with admin role
        diamond = new MockDiamond(admin);
        
        // Set treasury in diamond
        diamond.setTreasury(treasury);
        
        // Deploy BTR token
        btr = new BTR(NAME, SYMBOL, address(diamond), MAX_SUPPLY);
        
        // Deploy mock bridge
        bridge = new MockBridge();
        bridge.initialize(address(btr));
        
        // Set bridge limits in BTR
        uint256 mintLimit = 10_000_000 * 10**18;
        uint256 burnLimit = 10_000_000 * 10**18;
        vm.prank(admin);
        btr.setLimits(address(bridge), mintLimit, burnLimit);
        
        // Fund users with ETH for gas
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
        vm.deal(blacklisted, 10 ether);
    }
    
    /*********************************
     *       Basic Token Tests       *
     *********************************/
    
    function testInitialState() public {
        assertEq(btr.name(), NAME);
        assertEq(btr.symbol(), SYMBOL);
        assertEq(btr.decimals(), 18);
        assertEq(btr.totalSupply(), 0);
        assertEq(btr.maxSupply(), MAX_SUPPLY);
        assertEq(btr.genesisMinted(), false);
    }
    
    function testGenesisMint() public {
        vm.prank(admin);
        
        vm.expectEmit(true, true, true, true);
        emit GenesisMint(treasury, GENESIS_MINT_AMOUNT);
        
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), treasury, GENESIS_MINT_AMOUNT);
        
        btr.mintGenesis(GENESIS_MINT_AMOUNT);
        
        assertEq(btr.totalSupply(), GENESIS_MINT_AMOUNT);
        assertEq(btr.balanceOf(treasury), GENESIS_MINT_AMOUNT);
        assertEq(btr.genesisMinted(), true);
    }
    
    function testGenesisCanOnlyMintOnce() public {
        // First mint
        vm.prank(admin);
        btr.mintGenesis(GENESIS_MINT_AMOUNT);
        
        // Second attempt should fail
        vm.prank(admin);
        vm.expectRevert(BTR.GenesisAlreadyMinted.selector);
        btr.mintGenesis(100 * 10**18);
    }
    
    function testGenesisMintRequiresAdmin() public {
        vm.prank(user1);
        vm.expectRevert(); // Should revert with access control error
        btr.mintGenesis(GENESIS_MINT_AMOUNT);
    }
    
    function testGenesisMintCannotExceedMaxSupply() public {
        vm.prank(admin);
        vm.expectRevert(BTR.MaxSupplyExceeded.selector);
        btr.mintGenesis(MAX_SUPPLY + 1);
    }
    
    function testGenesisMintCannotBeZero() public {
        vm.prank(admin);
        vm.expectRevert(BTR.InvalidAmount.selector);
        btr.mintGenesis(0);
    }
    
    function testMintToTreasury() public {
        uint256 mintAmount = 1_000_000 * 10**18;
        
        vm.prank(admin);
        
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), treasury, mintAmount);
        
        btr.mintToTreasury(mintAmount);
        
        assertEq(btr.totalSupply(), mintAmount);
        assertEq(btr.balanceOf(treasury), mintAmount);
    }
    
    function testMintToTreasuryRequiresAdmin() public {
        vm.prank(user1);
        vm.expectRevert(); // Should revert with access control error
        btr.mintToTreasury(1_000_000 * 10**18);
    }
    
    function testMintToTreasuryCannotExceedMaxSupply() public {
        vm.prank(admin);
        vm.expectRevert(BTR.MaxSupplyExceeded.selector);
        btr.mintToTreasury(MAX_SUPPLY + 1);
    }
    
    function testMintToTreasuryCannotBeZero() public {
        vm.prank(admin);
        vm.expectRevert(BTR.InvalidAmount.selector);
        btr.mintToTreasury(0);
    }
    
    function testSetMaxSupply() public {
        uint256 newMaxSupply = 2_000_000_000 * 10**18;
        
        vm.prank(admin);
        
        vm.expectEmit(true, true, true, true);
        emit MaxSupplyUpdated(newMaxSupply);
        
        btr.setMaxSupply(newMaxSupply);
        
        assertEq(btr.maxSupply(), newMaxSupply);
    }
    
    function testSetMaxSupplyRequiresAdmin() public {
        vm.prank(user1);
        vm.expectRevert(); // Should revert with access control error
        btr.setMaxSupply(2_000_000_000 * 10**18);
    }
    
    function testSetMaxSupplyCannotBeZero() public {
        vm.prank(admin);
        vm.expectRevert(BTR.InvalidMaxSupply.selector);
        btr.setMaxSupply(0);
    }
    
    function testSetMaxSupplyCannotBeLessThanTotalSupply() public {
        // First mint some tokens
        vm.prank(admin);
        btr.mintToTreasury(100_000_000 * 10**18);
        
        // Now try to set max supply below total supply
        vm.prank(admin);
        vm.expectRevert(BTR.InvalidMaxSupply.selector);
        btr.setMaxSupply(50_000_000 * 10**18);
    }
    
    function testTreasuryFunction() public {
        assertEq(btr.treasury(), treasury);
        
        // Test with no treasury
        MockDiamond noDiamond = new MockDiamond(admin);
        BTR noBtr = new BTR(NAME, SYMBOL, address(noDiamond), MAX_SUPPLY);
        
        vm.expectRevert(BTR.NoTreasuryAddressFound.selector);
        noBtr.treasury();
    }
    
    /*********************************
     *       ERC20 Basic Tests       *
     *********************************/
    
    function testTransfer() public {
        // Setup: mint tokens to user1
        vm.prank(admin);
        btr.mintGenesis(GENESIS_MINT_AMOUNT);
        
        // Transfer from treasury to user1
        uint256 transferAmount = 1_000 * 10**18;
        vm.prank(treasury);
        
        vm.expectEmit(true, true, true, true);
        emit Transfer(treasury, user1, transferAmount);
        
        bool success = btr.transfer(user1, transferAmount);
        
        assertTrue(success);
        assertEq(btr.balanceOf(user1), transferAmount);
        assertEq(btr.balanceOf(treasury), GENESIS_MINT_AMOUNT - transferAmount);
    }
    
    function testApproveAndTransferFrom() public {
        // Setup: mint tokens to user1
        vm.prank(admin);
        btr.mintGenesis(GENESIS_MINT_AMOUNT);
        
        vm.prank(treasury);
        btr.transfer(user1, 1_000 * 10**18);
        
        // Approve user2 to spend user1's tokens
        uint256 approveAmount = 500 * 10**18;
        vm.prank(user1);
        
        vm.expectEmit(true, true, true, true);
        emit Approval(user1, user2, approveAmount);
        
        bool success = btr.approve(user2, approveAmount);
        
        assertTrue(success);
        assertEq(btr.allowance(user1, user2), approveAmount);
        
        // User2 transfers tokens from user1 to user3
        uint256 transferAmount = 300 * 10**18;
        vm.prank(user2);
        
        vm.expectEmit(true, true, true, true);
        emit Transfer(user1, user3, transferAmount);
        
        success = btr.transferFrom(user1, user3, transferAmount);
        
        assertTrue(success);
        assertEq(btr.balanceOf(user1), 1_000 * 10**18 - transferAmount);
        assertEq(btr.balanceOf(user3), transferAmount);
        assertEq(btr.allowance(user1, user2), approveAmount - transferAmount);
    }
    
    /*********************************
     *     Blacklisting Tests        *
     *********************************/
    
    function testBlacklisting() public {
        // Setup: mint tokens and distribute
        vm.prank(admin);
        btr.mintGenesis(GENESIS_MINT_AMOUNT);
        
        vm.prank(treasury);
        btr.transfer(user1, 1_000 * 10**18);
        
        vm.prank(user1);
        btr.transfer(blacklisted, 500 * 10**18);
        
        // Blacklist an address
        diamond.addToBlacklist(blacklisted);
        
        // Blacklisted address should not be able to transfer
        vm.prank(blacklisted);
        vm.expectRevert(BTR.TransferRestricted.selector);
        btr.transfer(user2, 100 * 10**18);
        
        // Others should not be able to transfer to blacklisted
        vm.prank(user1);
        vm.expectRevert(BTR.TransferRestricted.selector);
        btr.transfer(blacklisted, 100 * 10**18);
        
        // Remove from blacklist and verify transfers work again
        diamond.removeFromBlacklist(blacklisted);
        
        vm.prank(blacklisted);
        bool success = btr.transfer(user2, 100 * 10**18);
        assertTrue(success);
        assertEq(btr.balanceOf(user2), 100 * 10**18);
    }
    
    /*********************************
     *       Bridging Tests          *
     *********************************/
    
    function testBridgeLimits() public {
        // Set bridge limits
        uint256 newMintLimit = 20_000_000 * 10**18;
        uint256 newBurnLimit = 15_000_000 * 10**18;
        
        vm.prank(admin);
        
        vm.expectEmit(true, true, true, true);
        emit BridgeLimitsSet(newMintLimit, newBurnLimit, address(bridge));
        
        btr.setLimits(address(bridge), newMintLimit, newBurnLimit);
        
        // Verify limits
        assertEq(btr.mintingMaxLimitOf(address(bridge)), newMintLimit);
        assertEq(btr.burningMaxLimitOf(address(bridge)), newBurnLimit);
        assertEq(btr.mintingCurrentLimitOf(address(bridge)), newMintLimit);
        assertEq(btr.burningCurrentLimitOf(address(bridge)), newBurnLimit);
    }
    
    function testBridgeLimitsRequireAdmin() public {
        vm.prank(user1);
        vm.expectRevert(); // Should revert with access control error
        btr.setLimits(address(bridge), 1000 * 10**18, 1000 * 10**18);
    }
    
    function testRemoveBridge() public {
        vm.prank(admin);
        
        vm.expectEmit(true, true, true, true);
        emit BridgeLimitsSet(0, 0, address(bridge));
        
        btr.removeBridge(address(bridge));
        
        // Verify bridge is removed
        assertEq(btr.mintingMaxLimitOf(address(bridge)), 0);
        assertEq(btr.burningMaxLimitOf(address(bridge)), 0);
    }
    
    function testRemoveBridgeRequiresAdmin() public {
        vm.prank(user1);
        vm.expectRevert(); // Should revert with access control error
        btr.removeBridge(address(bridge));
    }
    
    function testCrosschainMint() public {
        uint256 mintAmount = 1_000 * 10**18;
        
        vm.prank(address(bridge));
        
        vm.expectEmit(true, true, true, true);
        emit CrosschainMint(user1, mintAmount, address(bridge));
        
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), user1, mintAmount);
        
        btr.crosschainMint(user1, mintAmount);
        
        assertEq(btr.balanceOf(user1), mintAmount);
        assertEq(btr.totalSupply(), mintAmount);
        
        // Check rate limit was updated
        assertEq(btr.mintingCurrentLimitOf(address(bridge)), 10_000_000 * 10**18 - mintAmount);
    }
    
    function testCrosschainBurn() public {
        // Setup: mint tokens to user1
        vm.prank(address(bridge));
        btr.crosschainMint(user1, 1_000 * 10**18);
        
        // Approve bridge to spend user1's tokens
        vm.prank(user1);
        btr.approve(address(bridge), 1_000 * 10**18);
        
        uint256 burnAmount = 500 * 10**18;
        
        vm.prank(address(bridge));
        
        vm.expectEmit(true, true, true, true);
        emit CrosschainBurn(user1, burnAmount, address(bridge));
        
        vm.expectEmit(true, true, true, true);
        emit Transfer(user1, address(0), burnAmount);
        
        btr.crosschainBurn(user1, burnAmount);
        
        assertEq(btr.balanceOf(user1), 500 * 10**18);
        assertEq(btr.totalSupply(), 500 * 10**18);
        
        // Check rate limit was updated
        assertEq(btr.burningCurrentLimitOf(address(bridge)), 10_000_000 * 10**18 - burnAmount);
    }
    
    function testIXERC20MintAndBurn() public {
        uint256 mintAmount = 1_000 * 10**18;
        
        vm.prank(address(bridge));
        
        vm.expectEmit(true, true, true, true);
        emit CrosschainMint(user1, mintAmount, address(bridge));
        
        btr.mint(user1, mintAmount);
        
        assertEq(btr.balanceOf(user1), mintAmount);
        
        // Approve bridge to spend user1's tokens
        vm.prank(user1);
        btr.approve(address(bridge), mintAmount);
        
        uint256 burnAmount = 500 * 10**18;
        
        vm.prank(address(bridge));
        
        vm.expectEmit(true, true, true, true);
        emit CrosschainBurn(user1, burnAmount, address(bridge));
        
        btr.burn(user1, burnAmount);
        
        assertEq(btr.balanceOf(user1), mintAmount - burnAmount);
    }
    
    function testMintExceedingMaxSupply() public {
        // Setup: mint almost max supply
        vm.prank(admin);
        btr.mintGenesis(MAX_SUPPLY - 100);
        
        // Try to mint more than remaining max supply
        vm.prank(address(bridge));
        vm.expectRevert(BTR.MaxSupplyExceeded.selector);
        btr.crosschainMint(user1, 101);
    }
    
    function testMintExceedingBridgeLimit() public {
        // Try to mint more than bridge limit
        vm.prank(address(bridge));
        vm.expectRevert(); // Should revert with bridge limit error
        btr.crosschainMint(user1, 20_000_000 * 10**18);
    }
    
    function testRateLimitUpdates() public {
        // First perform some minting
        vm.prank(address(bridge));
        btr.crosschainMint(user1, 1_000_000 * 10**18);
        
        // Fast forward time past rate limit period
        vm.warp(block.timestamp + 1 days + 1);
        
        // Check rate limit was reset
        assertEq(btr.mintingCurrentLimitOf(address(bridge)), 10_000_000 * 10**18);
        
        // Update rate limit period
        vm.prank(admin);
        
        vm.expectEmit(true, true, true, true);
        emit RateLimitPeriodUpdated(7 days);
        
        btr.setRateLimitPeriod(7 days);
        
        // Fast forward only 2 days
        vm.warp(block.timestamp + 2 days);
        
        // Mint again
        vm.prank(address(bridge));
        btr.crosschainMint(user1, 2_000_000 * 10**18);
        
        // The limit should reflect the new amount
        assertEq(btr.mintingCurrentLimitOf(address(bridge)), 8_000_000 * 10**18);
        
        // Fast forward 7 days
        vm.warp(block.timestamp + 7 days);
        
        // Check rate limit was reset again
        assertEq(btr.mintingCurrentLimitOf(address(bridge)), 10_000_000 * 10**18);
    }
    
    function testZeroAmountMintAndBurn() public {
        // Try to mint zero amount
        vm.prank(address(bridge));
        vm.expectRevert(BTR.ZeroAmount.selector);
        btr.crosschainMint(user1, 0);
        
        // Setup: mint tokens to user1
        vm.prank(address(bridge));
        btr.crosschainMint(user1, 1_000 * 10**18);
        
        // Approve bridge to spend user1's tokens
        vm.prank(user1);
        btr.approve(address(bridge), 1_000 * 10**18);
        
        // Try to burn zero amount
        vm.prank(address(bridge));
        vm.expectRevert(BTR.ZeroAmount.selector);
        btr.crosschainBurn(user1, 0);
    }
    
    /*********************************
     *       Interface Tests         *
     *********************************/
    
    function testSupportsInterfaces() public {
        assertTrue(btr.supportsInterface(type(IERC165).interfaceId));
        assertTrue(btr.supportsInterface(type(IERC20).interfaceId));
        assertTrue(btr.supportsInterface(type(IERC20Permit).interfaceId));
    }
    
    /*********************************
     *       Advanced Tests          *
     *********************************/
    
    function testUpdateBridgeLimits() public {
        // First perform some minting
        vm.prank(address(bridge));
        btr.crosschainMint(user1, 1_000_000 * 10**18);
        
        // Update mint limit
        vm.prank(admin);
        btr.updateMintLimit(address(bridge), 5_000_000 * 10**18, false);
        
        // Check current limit reflects both the new max and the used amount
        assertEq(btr.mintingMaxLimitOf(address(bridge)), 5_000_000 * 10**18);
        assertEq(btr.mintingCurrentLimitOf(address(bridge)), 4_000_000 * 10**18);
        
        // Update with reset counter
        vm.prank(admin);
        btr.updateMintLimit(address(bridge), 20_000_000 * 10**18, true);
        
        // Check limit was reset
        assertEq(btr.mintingMaxLimitOf(address(bridge)), 20_000_000 * 10**18);
        assertEq(btr.mintingCurrentLimitOf(address(bridge)), 20_000_000 * 10**18);
        
        // Same for burn limits
        vm.prank(address(bridge));
        btr.crosschainMint(user1, 2_000_000 * 10**18);
        
        vm.prank(user1);
        btr.approve(address(bridge), 1_000_000 * 10**18);
        
        vm.prank(address(bridge));
        btr.crosschainBurn(user1, 1_000_000 * 10**18);
        
        vm.prank(admin);
        btr.updateBurnLimit(address(bridge), 5_000_000 * 10**18, false);
        
        assertEq(btr.burningMaxLimitOf(address(bridge)), 5_000_000 * 10**18);
        assertEq(btr.burningCurrentLimitOf(address(bridge)), 4_000_000 * 10**18);
        
        vm.prank(admin);
        btr.updateBurnLimit(address(bridge), 15_000_000 * 10**18, true);
        
        assertEq(btr.burningMaxLimitOf(address(bridge)), 15_000_000 * 10**18);
        assertEq(btr.burningCurrentLimitOf(address(bridge)), 15_000_000 * 10**18);
    }
    
    function testUpdateBridgeLimitsRequiresAdmin() public {
        vm.prank(user1);
        vm.expectRevert(); // Should revert with access control error
        btr.updateMintLimit(address(bridge), 1000 * 10**18, false);
        
        vm.prank(user1);
        vm.expectRevert(); // Should revert with access control error
        btr.updateBurnLimit(address(bridge), 1000 * 10**18, false);
    }
    
    /*********************************
     *       Fuzzing Tests           *
     *********************************/
    
    function testFuzz_Transfer(uint256 amount) public {
        // Bound the amount to valid values
        amount = bound(amount, 1, MAX_SUPPLY);
        
        // Setup: mint tokens to treasury
        vm.prank(admin);
        btr.mintGenesis(amount);
        
        vm.prank(treasury);
        bool success = btr.transfer(user1, amount / 2);
        
        assertTrue(success);
        assertEq(btr.balanceOf(user1), amount / 2);
        assertEq(btr.balanceOf(treasury), amount - (amount / 2));
    }
    
    function testFuzz_CrosschainMint(uint256 amount) public {
        // Bound the amount to valid values
        amount = bound(amount, 1, 10_000_000 * 10**18);
        
        vm.prank(address(bridge));
        btr.crosschainMint(user1, amount);
        
        assertEq(btr.balanceOf(user1), amount);
        assertEq(btr.totalSupply(), amount);
    }
} 