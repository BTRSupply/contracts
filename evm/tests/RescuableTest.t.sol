// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {DiamondDeployer} from "@utils/DiamondDeployer.sol";
import {RescueFacet} from "@facets/RescueFacet.sol";
import {LibRescue} from "@libraries/LibRescue.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IDiamondCut} from "@interfaces/IDiamondCut.sol";
import {TokenType, ErrorType} from "@/BTRTypes.sol";
import {BTRErrors as Errors} from "@libraries/BTREvents.sol";

contract RescueTest is Test {
    DiamondDeployer.Deployment deployment;
    address admin;
    address treasury;
    address token;
    uint256 amount = 1 ether;

    function setUp() public {
        admin = address(this);
        treasury = address(0x1);
        token = address(0x2);

        DiamondDeployer diamondDeployer = new DiamondDeployer();
        deployment = diamondDeployer.deployDiamond(admin);

        // Add RescueFacet
        RescueFacet rescueFacet = new RescueFacet();
        bytes4[] memory selectors = new bytes4[](10);
        selectors[0] = RescueFacet.getRescueRequest.selector;
        selectors[1] = RescueFacet.isRescueLocked.selector;
        selectors[2] = RescueFacet.isRescueExpired.selector;
        selectors[3] = RescueFacet.isRescueUnlocked.selector;
        selectors[4] = RescueFacet.getRescueConfig.selector;
        selectors[5] = RescueFacet.setRescueConfig.selector;
        selectors[6] = RescueFacet.requestRescueERC20.selector;
        selectors[7] = RescueFacet.rescue.selector;
        selectors[8] = RescueFacet.cancelRescue.selector;
        selectors[9] = RescueFacet.initialize.selector;

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(rescueFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });

        IDiamondCut(address(deployment.diamond)).diamondCut(cuts, address(0), "");
    }

    function testRescueTokens() public {
        // Mock token balance
        vm.mockCall(
            token,
            abi.encodeWithSelector(IERC20.balanceOf.selector, address(deployment.diamond)),
            abi.encode(amount)
        );

        // Mock transfer success
        vm.mockCall(
            token,
            abi.encodeWithSelector(IERC20.transfer.selector, treasury, amount),
            abi.encode(true)
        );

        // Request rescue
        address[] memory tokens = new address[](1);
        tokens[0] = token;
        RescueFacet(payable(address(deployment.diamond))).requestRescueERC20(tokens);
        
        // Fast forward past timelock
        vm.warp(block.timestamp + 3 days);
        
        // Execute rescue
        RescueFacet(payable(address(deployment.diamond))).rescue(admin, TokenType.ERC20);

        // Verify transfer was called with correct parameters
        vm.expectCall(
            token,
            abi.encodeWithSelector(IERC20.transfer.selector, treasury, amount)
        );
    }

    function testRescueETH() public {
        // Fund contract with ETH
        vm.deal(address(deployment.diamond), amount);

        // Get initial treasury balance
        uint256 initialBalance = treasury.balance;

        // Request rescue
        RescueFacet(payable(address(deployment.diamond))).requestRescueNative();
        
        // Fast forward past timelock
        vm.warp(block.timestamp + 3 days);
        
        // Execute rescue
        RescueFacet(payable(address(deployment.diamond))).rescue(admin, TokenType.NATIVE);

        // Verify ETH was transferred
        assertEq(treasury.balance - initialBalance, amount);
        assertEq(address(deployment.diamond).balance, 0);
    }

    function testRescueTokensOnlyAdmin() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.Unauthorized.selector, ErrorType.RESCUE));
        vm.prank(address(0x3));
        
        address[] memory tokens = new address[](1);
        tokens[0] = token;
        RescueFacet(payable(address(deployment.diamond))).requestRescueERC20(tokens);
    }

    function testRescueETHOnlyAdmin() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.Unauthorized.selector, ErrorType.RESCUE));
        vm.prank(address(0x3));
        RescueFacet(payable(address(deployment.diamond))).requestRescueNative();
    }
} 