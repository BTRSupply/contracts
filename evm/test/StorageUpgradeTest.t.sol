// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {DiamondDeployer} from "../utils/DiamondDeployer.sol";
import {BTRStorage as S} from "../libraries/BTRStorage.sol";
import {DiamondStorage} from "../BTRTypes.sol";

contract StorageUpgradeTest is Test {
    DiamondDeployer.Deployment deployment;
    address admin;

    function setUp() public {
        admin = address(this);
        DiamondDeployer diamondDeployer = new DiamondDeployer();
        deployment = diamondDeployer.deployDiamond(admin);
    }

    function testDiamondStorageLayout() public {
        DiamondStorage storage ds = S.diamond();
        
        // Test facet storage
        assertEq(ds.facetAddresses.length, 2); // DiamondCutFacet + DiamondLoupeFacet
        assertTrue(ds.facetAddressPosition[address(deployment.diamondCutFacet)] == 0);
        assertTrue(ds.facetAddressPosition[address(deployment.diamondLoupeFacet)] == 1);
        
        // Test selector storage
        bytes4[] memory selectors = IDiamondLoupe(address(deployment.diamond)).facetFunctionSelectors(address(deployment.diamondLoupeFacet));
        for (uint256 i = 0; i < selectors.length; i++) {
            bytes32 position = ds.facetAddressAndSelectorPosition[selectors[i]];
            address facet = address(bytes20(position));
            assertTrue(facet == address(deployment.diamondLoupeFacet));
        }
    }

    function testStorageSlotCollision() public {
        // Get storage slots for different storage variables
        bytes32 diamondSlot = S.DIAMOND_STORAGE_POSITION;
        bytes32 accessControlSlot = S.ACCESS_CONTROL_STORAGE_POSITION;
        
        // Verify slots are different
        assertTrue(diamondSlot != accessControlSlot);
    }
} 