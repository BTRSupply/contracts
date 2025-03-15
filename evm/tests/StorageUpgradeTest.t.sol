// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {DiamondDeployer} from "@utils/DiamondDeployer.sol";
import {BTRStorage as S} from "@libraries/BTRStorage.sol";
import {Diamond, FacetAddressAndPosition} from "@/BTRTypes.sol";
import {IDiamondLoupe} from "@interfaces/IDiamondLoupe.sol";

contract StorageUpgradeTest is Test {
    DiamondDeployer.Deployment deployment;
    address admin;

    function setUp() public {
        admin = address(this);
        DiamondDeployer diamondDeployer = new DiamondDeployer();
        deployment = diamondDeployer.deployDiamond(admin);
    }

    function testDiamondLayout() public view {
        Diamond storage ds = S.diamond();
        
        // Test facet storage
        assertEq(ds.facetAddresses.length, 2); // DiamondCutFacet + DiamondLoupeFacet
        assertTrue(ds.facetFunctionSelectors[address(deployment.diamondCutFacet)].functionSelectors.length > 0);
        assertTrue(ds.facetFunctionSelectors[address(deployment.diamondLoupeFacet)].functionSelectors.length > 0);
        
        // Test selector storage
        bytes4[] memory selectors = IDiamondLoupe(address(deployment.diamond)).facetFunctionSelectors(address(deployment.diamondLoupeFacet));
        for (uint256 i = 0; i < selectors.length; i++) {
            FacetAddressAndPosition memory facetInfo = ds.selectorToFacetAndPosition[selectors[i]];
            address facet = facetInfo.facetAddress;
            assertTrue(facet == address(deployment.diamondLoupeFacet));
        }
    }

    function testStorageSlotCollision() public pure {
        // Get storage slots for different storage variables
        bytes32 diamondSlot = S.DIAMOND_NAMESPACE;
        bytes32 coreSlot = S.CORE_NAMESPACE;
        bytes32 rescueSlot = S.RESCUE_STORAGE_SLOT;
        
        // Ensure they are different
        assertTrue(diamondSlot != coreSlot);
        assertTrue(diamondSlot != rescueSlot);
        assertTrue(coreSlot != rescueSlot);
    }
} 