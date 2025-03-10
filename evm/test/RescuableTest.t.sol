// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {DiamondDeployer} from "../utils/DiamondDeployer.sol";
import {RescuableFacet} from "../facets/RescuableFacet.sol";
import {LibRescuable} from "../libraries/LibRescuable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RescuableTest is Test {
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

        // Add RescuableFacet
        RescuableFacet rescuableFacet = new RescuableFacet();
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = RescuableFacet.rescueTokens.selector;
        selectors[1] = RescuableFacet.rescueETH.selector;

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(rescuableFacet),
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

        // Rescue tokens
        RescuableFacet(address(deployment.diamond)).rescueTokens(token, treasury);

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

        // Rescue ETH
        RescuableFacet(address(deployment.diamond)).rescueETH(treasury);

        // Verify ETH was transferred
        assertEq(treasury.balance - initialBalance, amount);
        assertEq(address(deployment.diamond).balance, 0);
    }

    function testRescueTokensOnlyAdmin() public {
        vm.expectRevert(abi.encodeWithSelector(LibRescuable.NotAuthorized.selector));
        vm.prank(address(0x3));
        RescuableFacet(address(deployment.diamond)).rescueTokens(token, treasury);
    }

    function testRescueETHOnlyAdmin() public {
        vm.expectRevert(abi.encodeWithSelector(LibRescuable.NotAuthorized.selector));
        vm.prank(address(0x3));
        RescuableFacet(address(deployment.diamond)).rescueETH(treasury);
    }
} 