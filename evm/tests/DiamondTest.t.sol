// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {DiamondDeployer} from "../utils/DiamondDeployer.sol";
import {IDiamondCut} from "../interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../interfaces/IDiamondLoupe.sol";
import {DiamondLoupeFacet} from "../facets/DiamondLoupeFacet.sol";

contract DiamondTest is Test {
    DiamondDeployer.Deployment deployment;
    
    function setUp() public {
        DiamondDeployer diamondDeployer = new DiamondDeployer();
        deployment = diamondDeployer.deployDiamond(address(this));
    }

    function testAddFacet() public {
        // Verify facet was added correctly
        address[] memory facetAddresses = IDiamondLoupe(address(deployment.diamond)).facetAddresses();
        assertEq(facetAddresses.length, 2); // DiamondCutFacet + DiamondLoupeFacet
    }

    function testRemoveFacet() public {
        // Get initial facet count
        address[] memory facetAddresses = IDiamondLoupe(address(deployment.diamond)).facetAddresses();
        uint256 initialFacetCount = facetAddresses.length;

        // Get DiamondLoupeFacet selectors
        bytes4[] memory selectors = IDiamondLoupe(address(deployment.diamond)).facetFunctionSelectors(address(deployment.diamondLoupeFacet));

        // Prepare facet cut for removal
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(0),
            action: IDiamondCut.FacetCutAction.Remove,
            functionSelectors: selectors
        });

        // Remove facet
        IDiamondCut(address(deployment.diamond)).diamondCut(cuts, address(0), "");

        // Verify facet was removed
        facetAddresses = IDiamondLoupe(address(deployment.diamond)).facetAddresses();
        assertEq(facetAddresses.length, initialFacetCount - 1);
    }

    function testReplaceFacet() public {
        // Deploy new DiamondLoupeFacet
        DiamondLoupeFacet newLoupeFacet = new DiamondLoupeFacet();

        // Get DiamondLoupeFacet selectors
        bytes4[] memory selectors = IDiamondLoupe(address(deployment.diamond)).facetFunctionSelectors(address(deployment.diamondLoupeFacet));

        // Prepare facet cut for replacement
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(newLoupeFacet),
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: selectors
        });

        // Replace facet
        IDiamondCut(address(deployment.diamond)).diamondCut(cuts, address(0), "");

        // Verify facet was replaced
        address facetAddress = IDiamondLoupe(address(deployment.diamond)).facetAddress(selectors[0]);
        assertEq(facetAddress, address(newLoupeFacet));
    }
}
