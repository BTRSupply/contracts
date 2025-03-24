// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {BaseTest} from "../BaseTest.t.sol";
import {DiamondDeployer} from "@utils/generated/DiamondDeployer.gen.sol";
import {DiamondCutFacet} from "@facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "@facets/DiamondLoupeFacet.sol";
import {AccessControlFacet} from "@facets/AccessControlFacet.sol";
import {ManagementFacet} from "@facets/ManagementFacet.sol";
import {LibAccessControl} from "@libraries/LibAccessControl.sol";
import {BTRDiamond} from "@/BTRDiamond.sol";
import {IDiamondCut} from "@interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "@interfaces/IDiamondLoupe.sol";

/**
 * @title DiamondTest
 * @notice Tests for the main diamond features
 */
contract DiamondTest is BaseTest {
    DiamondDeployer public deployer;
    
    function setUp() public override {
        // Set admin address
        admin = address(this);
        
        // Create the deployer - this test uses its own diamond deployment
        // instead of inheriting from BaseTest
        deployer = new DiamondDeployer();
        
        // Deploy using the deployer - the deployer handles all facet setup
        DiamondDeployer.Deployment memory deployment = deployer.deployDiamond(admin);
        diamond = payable(deployment.diamond);
        
        // Skip the rest of the BaseTest setup since we've deployed our own diamond
    }
    
    function testLoupe() public view {
        IDiamondLoupe loupe = IDiamondLoupe(diamond);
        
        // Test facet functions
        address[] memory facetAddresses = loupe.facetAddresses();
        assertTrue(facetAddresses.length > 0, "Should have facets registered");
        
        // Get facet function selectors
        bytes4[] memory selectors = loupe.facetFunctionSelectors(facetAddresses[0]);
        assertTrue(selectors.length > 0, "Should have function selectors");
        
        // Get facet address with function selector
        address facetAddress = loupe.facetAddress(selectors[0]);
        assertTrue(facetAddress != address(0), "Should resolve facet address");
        assertEq(facetAddress, facetAddresses[0], "Should match first facet address");
    }
    
    function testDiamondCut() public {
        // Deploy a new facet
        DiamondCutFacet newFacet = new DiamondCutFacet();
        
        // Prepare facet cut
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(newFacet),
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: deployer.getDiamondCutFacetSelectors()
        });
        
        // Execute cut as admin
        vm.startPrank(admin);
        IDiamondCut(diamond).diamondCut(cuts, address(0), new bytes(0));
        vm.stopPrank();
        
        // Verify the cut worked
        IDiamondLoupe loupe = IDiamondLoupe(diamond);
        address facetAddress = loupe.facetAddress(deployer.getDiamondCutFacetSelectors()[0]);
        assertEq(facetAddress, address(newFacet), "Facet should have been replaced");
    }
}
