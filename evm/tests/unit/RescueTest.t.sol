// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {BaseTest} from "../BaseTest.t.sol";
import {RescueFacet} from "@facets/RescueFacet.sol";
import {AccessControlFacet} from "@facets/AccessControlFacet.sol";
import {LibAccessControl} from "@libraries/LibAccessControl.sol";
import {TokenType, ErrorType} from "@/BTRTypes.sol";
import {BTRErrors as Errors} from "@libraries/BTREvents.sol";
import {TestToken} from "../mocks/TestToken.sol";
import {MockERC721} from "../mocks/MockERC721.sol";
import {MockERC1155} from "../mocks/MockERC1155.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {LibRescue} from "@libraries/LibRescue.sol";

/**
 * @title RescueTest
 * @notice Tests functionality for rescuing tokens from the diamond contract
 * @dev This test focuses exclusively on rescue operations and permissions
 */
contract RescueTest is BaseTest {
    RescueFacet public rescueFacet;
    TestToken public mockToken;
    MockERC721 public mockNFT;
    MockERC1155 public mockERC1155;

    uint256 constant RESCUE_AMOUNT = 1000 ether;
    uint256 constant NFT_ID = 123;
    uint256 constant NFT_ID_2 = 456;
    uint256 constant NFT_ID_3 = 789;
    uint256 constant ERC1155_ID = 456;
    uint256 constant ERC1155_AMOUNT = 10;
    
    // Allow the contract to receive ETH
    receive() external payable {}
    
    function setUp() public override {
        // Call the base setup first
        super.setUp();
        
        // Initialize the rescue facet
        rescueFacet = RescueFacet(diamond);
        
        // Deploy test tokens
        mockToken = new TestToken("Mock Token", "MOCK", 18);
        mockNFT = new MockERC721("Mock NFT", "MNFT");
        mockERC1155 = new MockERC1155("https://token.uri/");
    }
    
    // Helper functions to reduce code duplication
    function initRescueModule(uint256 lockDuration, uint256 validityPeriod) internal {
        vm.startPrank(admin);
        rescueFacet.initializeRescue();
        rescueFacet.setRescueConfig(uint64(lockDuration), uint64(validityPeriod));
        vm.stopPrank();
    }
    
    function initRescueModule() internal {
        initRescueModule(1 days, 7 days);
    }
    
    function advancePastTimelock() internal {
        vm.warp(block.timestamp + 1 days + 1 hours);
    }
    
    function sendEthToDiamond(uint256 amount) internal {
        vm.deal(admin, amount);
        vm.prank(admin);
        (bool success,) = address(diamond).call{value: amount}("");
        require(success, "ETH transfer failed");
    }
    
    function executeRescue(address recipient, TokenType tokenType) internal {
        vm.prank(manager);
        rescueFacet.rescue(recipient, tokenType);
    }

    function testRescueTokens() public {
        // Initialize rescue module
        initRescueModule();
        
        // Mint some tokens to the diamond contract
        mockToken.mint(address(diamond), RESCUE_AMOUNT);
        
        // Verify initial balances
        assertEq(mockToken.balanceOf(address(diamond)), RESCUE_AMOUNT);
        assertEq(mockToken.balanceOf(admin), 0);
        
        // Request a rescue as the admin
        vm.startPrank(admin);
        address[] memory tokens = new address[](1);
        tokens[0] = address(mockToken);
        rescueFacet.requestRescueERC20(tokens);
        vm.stopPrank();
        
        // Fast forward past the timelock
        advancePastTimelock();
        
        // Execute the rescue as the manager
        executeRescue(admin, TokenType.ERC20);
        
        // Verify the tokens were rescued
        assertEq(mockToken.balanceOf(address(diamond)), 0);
        assertEq(mockToken.balanceOf(admin), RESCUE_AMOUNT);
    }
    
    function testRescueETH() public {
        // Initialize rescue module
        initRescueModule();
        
        // Send ETH to the diamond
        sendEthToDiamond(1 ether);
        
        // Request a rescue
        vm.prank(admin);
        rescueFacet.requestRescueNative();
        
        // Fast forward past the timelock
        advancePastTimelock();
        
        uint256 initialBalance = admin.balance;
        
        // Execute the rescue
        executeRescue(admin, TokenType.NATIVE);
        
        // Verify the ETH was rescued
        assertEq(address(diamond).balance, 0);
        assertEq(admin.balance - initialBalance, 1 ether);
    }
    
    function testRescueERC721() public {
        // Initialize rescue module
        initRescueModule();
        
        // Mint an NFT to the diamond
        mockNFT.mint(address(diamond), NFT_ID);
        
        // Verify initial ownership
        assertEq(mockNFT.ownerOf(NFT_ID), address(diamond));
        
        // Request a rescue as the admin
        vm.startPrank(admin);
        rescueFacet.requestRescueERC721(address(mockNFT), NFT_ID);
        vm.stopPrank();
        
        // Fast forward past the timelock
        advancePastTimelock();
        
        // Execute the rescue as the manager
        executeRescue(admin, TokenType.ERC721);
        
        // Verify the NFT was rescued
        assertEq(mockNFT.ownerOf(NFT_ID), admin);
    }
    
    function testRescueERC1155() public {
        // Initialize rescue module
        initRescueModule();
        
        // Mint ERC1155 tokens to the diamond
        mockERC1155.mint(address(diamond), ERC1155_ID, ERC1155_AMOUNT, "");
        
        // Verify initial balances
        assertEq(mockERC1155.balanceOf(address(diamond), ERC1155_ID), ERC1155_AMOUNT);
        assertEq(mockERC1155.balanceOf(admin, ERC1155_ID), 0);
        
        // Request a rescue as the admin
        vm.startPrank(admin);
        rescueFacet.requestRescueERC1155(address(mockERC1155), ERC1155_ID);
        vm.stopPrank();
        
        // Fast forward past the timelock
        advancePastTimelock();
        
        // Execute the rescue as the manager
        executeRescue(admin, TokenType.ERC1155);
        
        // Verify the tokens were rescued
        assertEq(mockERC1155.balanceOf(address(diamond), ERC1155_ID), 0);
        assertEq(mockERC1155.balanceOf(admin, ERC1155_ID), ERC1155_AMOUNT);
    }
    
    function testRescueUnauthorized() public {
        // Initialize rescue module
        vm.startPrank(admin);
        rescueFacet.initializeRescue();
        vm.stopPrank();
        
        // Try to rescue as a non-manager
        vm.expectRevert();
        vm.prank(address(0xBEEF));
        rescueFacet.rescue(admin, TokenType.NATIVE);
    }
    
    function testRescueBeforeTimelock() public {
        // Initialize rescue module
        initRescueModule();
        
        // Send ETH to the diamond
        sendEthToDiamond(1 ether);
        
        // Request a rescue
        vm.prank(admin);
        rescueFacet.requestRescueNative();
        
        // Try to rescue before timelock expires (should fail)
        vm.prank(manager);
        vm.expectRevert();
        rescueFacet.rescue(admin, TokenType.NATIVE);
    }
    
    function testRescueMultipleERC721() public {
        // Initialize rescue module
        initRescueModule();
        
        // Mint multiple NFTs to the diamond
        mockNFT.mint(address(diamond), NFT_ID);
        mockNFT.mint(address(diamond), NFT_ID_2);
        mockNFT.mint(address(diamond), NFT_ID_3);
        
        // Request a rescue for all NFTs using batch function
        vm.startPrank(admin);
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = NFT_ID;
        tokenIds[1] = NFT_ID_2;
        tokenIds[2] = NFT_ID_3;
        rescueFacet.requestRescueERC721Batch(address(mockNFT), tokenIds);
        vm.stopPrank();
        
        // Fast forward past the timelock
        advancePastTimelock();
        
        // Rescue all NFTs
        executeRescue(admin, TokenType.ERC721);
        
        // Verify all NFTs were rescued
        assertEq(mockNFT.ownerOf(NFT_ID), admin);
        assertEq(mockNFT.ownerOf(NFT_ID_2), admin);
        assertEq(mockNFT.ownerOf(NFT_ID_3), admin);
    }
    
    function testRescueMultipleERC1155() public {
        // Initialize rescue module
        initRescueModule();
        
        // Define multiple token IDs
        uint256 tokenId1 = 111;
        uint256 tokenId2 = 222;
        uint256 amount1 = 5;
        uint256 amount2 = 10;
        
        // Mint ERC1155 tokens to the diamond
        mockERC1155.mint(address(diamond), tokenId1, amount1, "");
        mockERC1155.mint(address(diamond), tokenId2, amount2, "");
        
        // Request a rescue for all tokens using batch function
        vm.startPrank(admin);
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = tokenId1;
        tokenIds[1] = tokenId2;
        rescueFacet.requestRescueERC1155Batch(address(mockERC1155), tokenIds);
        vm.stopPrank();
        
        // Fast forward past the timelock
        advancePastTimelock();
        
        // Rescue all tokens
        executeRescue(admin, TokenType.ERC1155);
        
        // Verify all tokens were rescued
        assertEq(mockERC1155.balanceOf(address(diamond), tokenId1), 0);
        assertEq(mockERC1155.balanceOf(admin, tokenId1), amount1);
        assertEq(mockERC1155.balanceOf(address(diamond), tokenId2), 0);
        assertEq(mockERC1155.balanceOf(admin, tokenId2), amount2);
    }
    
    function testBatchERC20Rescue() public {
        // Initialize rescue module
        initRescueModule();
        
        // Create multiple tokens
        TestToken token1 = new TestToken("Token 1", "TK1", 18);
        TestToken token2 = new TestToken("Token 2", "TK2", 18);
        TestToken token3 = new TestToken("Token 3", "TK3", 18);
        
        // Mint tokens to the diamond
        token1.mint(address(diamond), RESCUE_AMOUNT);
        token2.mint(address(diamond), RESCUE_AMOUNT * 2);
        token3.mint(address(diamond), RESCUE_AMOUNT * 3);

        // Request rescues for all tokens in a single batch
        vm.startPrank(admin);
        address[] memory allTokens = new address[](3);
        allTokens[0] = address(token1);
        allTokens[1] = address(token2);
        allTokens[2] = address(token3);
        rescueFacet.requestRescueERC20(allTokens);
        vm.stopPrank();
        
        // Fast forward past the timelock
        advancePastTimelock();
        
        // Execute rescues
        executeRescue(admin, TokenType.ERC20);
        
        // Verify all tokens were rescued
        assertEq(token1.balanceOf(address(diamond)), 0);
        assertEq(token1.balanceOf(admin), RESCUE_AMOUNT);
        
        assertEq(token2.balanceOf(address(diamond)), 0);
        assertEq(token2.balanceOf(admin), RESCUE_AMOUNT * 2);
        
        assertEq(token3.balanceOf(address(diamond)), 0);
        assertEq(token3.balanceOf(admin), RESCUE_AMOUNT * 3);
    }
    
    function testRescueExpiry() public {
        // Initialize rescue module with a shorter validity period
        initRescueModule(1 days, 3 days);
        
        // Send ETH to the diamond
        sendEthToDiamond(1 ether);
        
        // Request a rescue
        vm.prank(admin);
        rescueFacet.requestRescueNative();
        
        // Fast forward past timelock but within validity period
        vm.warp(block.timestamp + 2 days);
        
        // Check status - should be UNLOCKED (2)
        uint256 status = rescueFacet.getRescueStatus(admin, TokenType.NATIVE);
        assertEq(status, 2, "Should be unlocked");
        
        // Fast forward past validity period
        vm.warp(block.timestamp + 2 days);
        
        // Check status - should be EXPIRED (3)
        status = rescueFacet.getRescueStatus(admin, TokenType.NATIVE);
        assertEq(status, 3, "Should be expired");
        
        // Try to rescue after expiry (should fail)
        vm.prank(manager);
        vm.expectRevert();
        rescueFacet.rescue(admin, TokenType.NATIVE);
    }
    
    function testCancelRescue() public {
        // Initialize rescue module
        initRescueModule();
        
        // Send ETH to the diamond
        sendEthToDiamond(1 ether);
        
        // Request a rescue
        vm.prank(admin);
        rescueFacet.requestRescueNative();
        
        // Cancel the rescue request
        vm.prank(admin);
        rescueFacet.cancelRescue(admin, TokenType.NATIVE);
        
        // Verify the rescue was cancelled
        uint256 status = rescueFacet.getRescueStatus(admin, TokenType.NATIVE);
        assertEq(status, 0, "Rescue should be cancelled (0)");
    }
    
    function testCancelAllRescues() public {
        // Initialize rescue module
        initRescueModule();
        
        // Send ETH to the diamond
        sendEthToDiamond(1 ether);
        
        // Mint tokens to the diamond
        mockToken.mint(address(diamond), RESCUE_AMOUNT);
        
        // Request rescues
        vm.startPrank(admin);
        rescueFacet.requestRescueNative();
        address[] memory tokens = new address[](1);
        tokens[0] = address(mockToken);
        rescueFacet.requestRescueERC20(tokens);
        vm.stopPrank();
        
        // Cancel all rescue requests
        vm.prank(admin);
        rescueFacet.cancelRescueAll(admin);
        
        // Verify all rescues were cancelled
        uint256 nativeStatus = rescueFacet.getRescueStatus(admin, TokenType.NATIVE);
        uint256 erc20Status = rescueFacet.getRescueStatus(admin, TokenType.ERC20);
        
        assertEq(nativeStatus, 0, "Native rescue should be cancelled");
        assertEq(erc20Status, 0, "ERC20 rescue should be cancelled");
    }
    
    function testRescueAllSimple() public {
        // Initialize rescue
        initRescueModule();
        
        // Send ETH to the diamond
        sendEthToDiamond(1 ether);
        
        // Request a rescue
        vm.prank(admin);
        rescueFacet.requestRescueNative();
        
        // Check status
        uint256 status = rescueFacet.getRescueStatus(admin, TokenType.NATIVE); 
        console.log("Status before timelock: %d", status);
        assertEq(status, 1, "Request should be pending");
        
        // Check if locked
        bool isLocked = rescueFacet.isRescueLocked(admin, TokenType.NATIVE);
        assertTrue(isLocked, "Request should be locked");
        
        // Time travel to unlock
        vm.warp(block.timestamp + 2 days);
        
        // Check status after timelock
        status = rescueFacet.getRescueStatus(admin, TokenType.NATIVE);
        console.log("Status after timelock: %d", status);
        
        // Check if unlocked
        bool isUnlocked = rescueFacet.isRescueUnlocked(admin, TokenType.NATIVE);
        assertTrue(isUnlocked, "Request should be unlocked");
        
        // Get admin balance before rescue
        uint256 adminBalanceBefore = admin.balance;
        console.log("Admin balance before: %d", adminBalanceBefore);
        
        // Rescue as manager
        vm.startPrank(manager);
        rescueFacet.rescueAll(admin);
        vm.stopPrank();
        
        // Check status after rescue
        status = rescueFacet.getRescueStatus(admin, TokenType.NATIVE);
        console.log("Status after rescue: %d", status);
        assertEq(status, 0, "Request should be cleared");
        
        // Verify admin received the ETH
        uint256 adminBalanceAfter = admin.balance;
        console.log("Admin balance after: %d", adminBalanceAfter);
        assertEq(adminBalanceAfter - adminBalanceBefore, 1 ether, "Admin should have received 1 ETH");
    }
    
    function testSupportsInterface() public {
        // Test that the diamond correctly implements the IERC721Receiver and IERC1155Receiver interfaces
        bool supportsERC721 = rescueFacet.supportsInterface(type(IERC721Receiver).interfaceId);
        bool supportsERC1155 = rescueFacet.supportsInterface(type(IERC1155Receiver).interfaceId);
        bool supportsERC165 = rescueFacet.supportsInterface(type(IERC165).interfaceId);
        
        assertTrue(supportsERC721, "Should support IERC721Receiver");
        assertTrue(supportsERC1155, "Should support IERC1155Receiver");
        assertTrue(supportsERC165, "Should support IERC165");
    }
    
    // New tests to achieve 100% coverage

    function testGetRescueRequest() public {
        // Initialize rescue module
        initRescueModule();
        
        // No request initially
        (uint64 timestamp, address tokenAddress, uint256 tokenIdsCount) = rescueFacet.getRescueRequest(admin, TokenType.NATIVE);
        assertEq(timestamp, 0, "Timestamp should be 0 initially");
        assertEq(tokenAddress, address(0), "Token address should be 0 initially");
        assertEq(tokenIdsCount, 0, "Token IDs count should be 0 initially");
        
        // Create a request
        vm.prank(admin);
        rescueFacet.requestRescueNative();
        
        // Verify request data
        (timestamp, tokenAddress, tokenIdsCount) = rescueFacet.getRescueRequest(admin, TokenType.NATIVE);
        assertEq(timestamp, uint64(block.timestamp), "Timestamp should match request time");
        assertEq(tokenAddress, address(1), "Token address should be address(1) for ETH");
        assertEq(tokenIdsCount, 0, "Native request should have 0 token IDs");
    }
    
    function testGetRescueConfig() public {
        // Initialize rescue module with custom config
        vm.startPrank(admin);
        rescueFacet.initializeRescue();
        
        // Check default config
        (uint64 timelock, uint64 validity) = rescueFacet.getRescueConfig();
        assertEq(timelock, 2 days, "Default timelock incorrect");
        assertEq(validity, 7 days, "Default validity incorrect");
        
        // Set new config
        uint64 newTimelock = 3 days;
        uint64 newValidity = 14 days;
        rescueFacet.setRescueConfig(newTimelock, newValidity);
        vm.stopPrank();
        
        // Verify new config
        (timelock, validity) = rescueFacet.getRescueConfig();
        assertEq(timelock, newTimelock, "Updated timelock incorrect");
        assertEq(validity, newValidity, "Updated validity incorrect");
    }
    
    function testInvalidRescueConfig() public {
        vm.startPrank(admin);
        rescueFacet.initializeRescue();
        
        // Test below min timelock
        uint64 belowMinTimelock = 1 days - 1;
        vm.expectRevert();
        rescueFacet.setRescueConfig(belowMinTimelock, 7 days);
        
        // Test above max timelock
        uint64 aboveMaxTimelock = 7 days + 1;
        vm.expectRevert();
        rescueFacet.setRescueConfig(aboveMaxTimelock, 7 days);
        
        // Test below min validity
        uint64 belowMinValidity = 1 days - 1;
        vm.expectRevert();
        rescueFacet.setRescueConfig(2 days, belowMinValidity);
        
        // Test above max validity
        uint64 aboveMaxValidity = 30 days + 1;
        vm.expectRevert();
        rescueFacet.setRescueConfig(2 days, aboveMaxValidity);
        
        vm.stopPrank();
    }
    
    function testUnauthorizedCancel() public {
        // Initialize rescue module
        initRescueModule();
        
        // Request a rescue
        vm.prank(admin);
        rescueFacet.requestRescueNative();
        
        // Try to cancel by unauthorized user
        address randomUser = address(0xBEEF);
        vm.prank(randomUser);
        vm.expectRevert(abi.encodeWithSelector(Errors.Unauthorized.selector, ErrorType.RESCUE));
        rescueFacet.cancelRescue(admin, TokenType.NATIVE);
        
        // Try to cancel all by unauthorized user
        vm.prank(randomUser);
        vm.expectRevert(abi.encodeWithSelector(Errors.Unauthorized.selector, ErrorType.RESCUE));
        rescueFacet.cancelRescueAll(admin);
    }
    
    function testRescueZeroTokens() public {
        // Initialize rescue module
        initRescueModule();
        
        // Request a rescue without sending any tokens
        vm.prank(admin);
        rescueFacet.requestRescueNative();
        
        // Fast forward past timelock
        advancePastTimelock();
        
        // Execute the rescue (should succeed but not transfer anything)
        uint256 initialBalance = admin.balance;
        executeRescue(admin, TokenType.NATIVE);
        assertEq(admin.balance, initialBalance, "Balance shouldn't change as there's nothing to rescue");
    }
    
    function testEmptyERC20TokenArray() public {
        // Initialize rescue module
        initRescueModule();
        
        // Try to request with empty array (should revert)
        vm.prank(admin);
        address[] memory emptyTokens = new address[](0);
        vm.expectRevert(Errors.InvalidParameter.selector);
        rescueFacet.requestRescueERC20(emptyTokens);
    }
    
    function testReinitialization() public {
        // Initialize rescue module
        vm.prank(admin);
        rescueFacet.initializeRescue();
        
        // Trying to initialize again should maintain the default values
        vm.prank(admin);
        rescueFacet.initializeRescue();
        
        // Verify the config is still the default
        (uint64 timelock, uint64 validity) = rescueFacet.getRescueConfig();
        assertEq(timelock, 2 days, "Timelock should be default");
        assertEq(validity, 7 days, "Validity should be default");
    }
    
    function testRescueWithNonExistentRequest() public {
        // Initialize rescue module
        initRescueModule();
        
        // Try to rescue without a request (should fail)
        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(Errors.NotFound.selector, ErrorType.RESCUE));
        rescueFacet.rescue(admin, TokenType.NATIVE);
    }
    
    function testIsRescueExpiredFunction() public {
        // Initialize rescue module
        initRescueModule(1 days, 3 days);
        
        // Request a rescue
        vm.prank(admin);
        rescueFacet.requestRescueNative();
        
        // Check initial state - should not be expired
        bool isExpired = rescueFacet.isRescueExpired(admin, TokenType.NATIVE);
        assertFalse(isExpired, "Rescue should not be expired initially");
        
        // Fast forward past validity period
        vm.warp(block.timestamp + 1 days + 3 days + 1);
        
        // Now should be expired
        isExpired = rescueFacet.isRescueExpired(admin, TokenType.NATIVE);
        assertTrue(isExpired, "Rescue should be expired after validity period");
    }
    
    function testRescueAllWithMixedStatuses() public {
        // Initialize rescue module
        initRescueModule();
        
        // Setup various token types
        sendEthToDiamond(1 ether);
        mockToken.mint(address(diamond), RESCUE_AMOUNT);
        
        // Request rescues
        vm.startPrank(admin);
        rescueFacet.requestRescueNative();
        
        address[] memory tokens = new address[](1);
        tokens[0] = address(mockToken);
        rescueFacet.requestRescueERC20(tokens);
        vm.stopPrank();
        
        // Fast forward past timelock
        advancePastTimelock();
        
        // Execute rescueAll
        vm.prank(manager);
        rescueFacet.rescueAll(admin);
        
        // Verify all tokens were rescued
        assertEq(address(diamond).balance, 0, "ETH should be rescued");
        assertEq(mockToken.balanceOf(address(diamond)), 0, "ERC20 should be rescued");
    }
    
    function testSelfCancelRescue() public {
        // Initialize rescue module
        initRescueModule();
        
        // Setup a rescue request for admin
        vm.prank(admin);
        rescueFacet.requestRescueNative();
        
        // Admin cancels their own rescue (this should work)
        vm.prank(admin);
        rescueFacet.cancelRescue(admin, TokenType.NATIVE);
        
        // Verify the rescue was cancelled
        uint8 status = rescueFacet.getRescueStatus(admin, TokenType.NATIVE);
        assertEq(status, 0, "Rescue should be cancelled");
    }
} 