// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {BaseTest} from "../BaseTest.t.sol";
import {BTRStorage as S} from "@libraries/BTRStorage.sol";
import {Diamond, FacetAddressAndPosition} from "@/BTRTypes.sol";
import {IDiamondLoupe} from "@interfaces/IDiamondLoupe.sol";

/**
 * @title StorageUpgradeTest
 * @notice Tests storage layout and prevents storage collisions
 * @dev This test focuses exclusively on storage layout in the diamond
 */
contract StorageUpgradeTest is BaseTest {
    function setUp() public override {
        // Call base setup which will deploy the diamond and set up roles
        super.setUp();
    }
    
    function testDiamondLayout() public view {
        // Access the diamond storage
        Diamond storage ds = S.diamond();
        
        // Get facet addresses using loupe
        IDiamondLoupe loupe = IDiamondLoupe(diamond);
        address[] memory facetAddresses = loupe.facetAddresses();
        
        // Find specific facets by their function selectors
        address diamondCutFacet;
        address diamondLoupeFacet;
        
        for (uint i = 0; i < facetAddresses.length; i++) {
            bytes4[] memory facetSelectors = loupe.facetFunctionSelectors(facetAddresses[i]);
            for (uint j = 0; j < facetSelectors.length; j++) {
                if (facetSelectors[j] == IDiamondLoupe.facetAddresses.selector) {
                    diamondLoupeFacet = facetAddresses[i];
                } else if (facetSelectors[j] == bytes4(keccak256("diamondCut(tuple[],address,bytes)"))) {
                    diamondCutFacet = facetAddresses[i];
                }
            }
        }
        
        require(diamondCutFacet != address(0), "DiamondCutFacet not found");
        require(diamondLoupeFacet != address(0), "DiamondLoupeFacet not found");
        
        // Test facet storage
        assertTrue(ds.facetAddresses.length >= 2, "Should have at least 2 facets");
        assertTrue(ds.facetFunctionSelectors[diamondCutFacet].functionSelectors.length > 0, "DiamondCutFacet should have selectors");
        assertTrue(ds.facetFunctionSelectors[diamondLoupeFacet].functionSelectors.length > 0, "DiamondLoupeFacet should have selectors");
        
        // Test selector storage
        bytes4[] memory loupeSelectors = loupe.facetFunctionSelectors(diamondLoupeFacet);
        for (uint256 i = 0; i < loupeSelectors.length; i++) {
            FacetAddressAndPosition memory facetInfo = ds.selectorToFacetAndPosition[loupeSelectors[i]];
            address facet = facetInfo.facetAddress;
            assertEq(facet, diamondLoupeFacet, "Selector should point to correct facet");
        }
    }
    
    function testStorageSlotCollision() public pure {
        // Get storage slots for different storage variables
        bytes32 diamondSlot = S.DIAMOND_NAMESPACE;
        bytes32 coreSlot = S.CORE_NAMESPACE;
        bytes32 rescueSlot = S.RESCUE_STORAGE_SLOT;
        
        // Ensure they are different
        assertTrue(diamondSlot != coreSlot, "Diamond and Core namespaces should not collide");
        assertTrue(diamondSlot != rescueSlot, "Diamond and Rescue slots should not collide");
        assertTrue(coreSlot != rescueSlot, "Core and Rescue slots should not collide");
    }
} 