// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {BaseTest} from "../BaseTest.t.sol";
import {IDiamondCut, IDiamondLoupe, IDiamond} from "@interfaces/IDiamond.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {DiamondCutFacet} from "@facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "@facets/DiamondLoupeFacet.sol";
import {AccessControlFacet} from "@facets/AccessControlFacet.sol";
import {BTRDiamond} from "@/BTRDiamond.sol";
import {LibDiamond as D} from "@libraries/LibDiamond.sol";
import {BTRStorage as S} from "@libraries/BTRStorage.sol";
import {ErrorType, Diamond} from "@/BTRTypes.sol";
import {BTRErrors as Errors} from "@libraries/BTREvents.sol";

contract FailingInitializer {
    function initialize() external pure {
        revert("Initialization failed");
    }
}

contract DiamondTest is BaseTest {
    DiamondCutFacet cutFacet;
    DiamondLoupeFacet loupeFacet;
    
    // Test function selectors
    bytes4 constant TEST_FUNC_1 = bytes4(keccak256("testFunc1()"));
    bytes4 constant TEST_FUNC_2 = bytes4(keccak256("testFunc2()"));
    bytes4 constant TEST_FUNC_3 = bytes4(keccak256("testFunc3()"));

    function setUp() public override {
        super.setUp();
        cutFacet = DiamondCutFacet(address(diamond));
        loupeFacet = DiamondLoupeFacet(address(diamond));
    }

    // FACET FUNCTIONS TESTS

    function testFacetFunctionSelectors() public {
        address[] memory facetAddresses = loupeFacet.facetAddresses();
        
        // Test normal case with existing facet
        bytes4[] memory selectors = loupeFacet.facetFunctionSelectors(facetAddresses[0]);
        assertTrue(selectors.length > 0, "No selectors for facet");
        
        // Test pagination with normal parameters
        selectors = loupeFacet.facetFunctionSelectorsPaginated(facetAddresses[0], 0, 3);
        assertLe(selectors.length, 3, "Should respect max limit");
        
        // Test edge cases
        selectors = loupeFacet.facetFunctionSelectorsPaginated(facetAddresses[0], 0, 0);
        assertEq(selectors.length, 0, "Zero limit should return empty array");
        
        selectors = loupeFacet.facetFunctionSelectorsPaginated(address(0), 0, 5);
        assertEq(selectors.length, 0, "Non-existent facet should return empty array");
    }

    function testFacetAddressForSelector() public {
        address[] memory facetAddresses = loupeFacet.facetAddresses();
        
        // Test existing selectors
        for (uint i = 0; i < facetAddresses.length; i++) {
            bytes4[] memory selectors = loupeFacet.facetFunctionSelectors(facetAddresses[i]);
            if (selectors.length > 0) {
                address facetAddr = loupeFacet.facetAddress(selectors[0]);
                assertEq(facetAddr, facetAddresses[i], "Facet address should match");
                break;
            }
        }
        
        // Test non-existent selector
        bytes4 nonExistentSelector = bytes4(keccak256("nonExistentFunction()"));
        address facetAddr = loupeFacet.facetAddress(nonExistentSelector);
        assertEq(facetAddr, address(0), "Non-existent selector should return zero address");
    }

    function testFacetAddresses() public {
        // Test normal function
        address[] memory facets = loupeFacet.facetAddresses();
        assertTrue(facets.length > 0, "Should have facets");
        
        // Test pagination with normal parameters
        address[] memory paginatedFacets = loupeFacet.facetAddressesPaginated(0, 2);
        assertLe(paginatedFacets.length, 2, "Should respect max limit");
        
        // Test edge cases
        paginatedFacets = loupeFacet.facetAddressesPaginated(0, 0);
        assertEq(paginatedFacets.length, 0, "Zero limit should return empty array");
        
        paginatedFacets = loupeFacet.facetAddressesPaginated(999, 5);
        assertEq(paginatedFacets.length, 0, "Out of range offset should return empty array");
    }

    function testSupportsInterface() public {
        assertTrue(loupeFacet.supportsInterface(type(IDiamondCut).interfaceId), "Should support IDiamondCut");
        assertTrue(loupeFacet.supportsInterface(type(IDiamondLoupe).interfaceId), "Should support IDiamondLoupe");
        assertFalse(loupeFacet.supportsInterface(bytes4(0xffffffff)), "Should not support invalid interface");
    }

    function testFacets() public {
        // Test facets() function
        IDiamondLoupe.Facet[] memory facets = loupeFacet.facets();
        assertTrue(facets.length > 0, "Should have facets");
        
        // Test pagination
        IDiamondLoupe.Facet[] memory paginatedFacets = loupeFacet.facetsPaginated(0, 2);
        assertLe(paginatedFacets.length, 2, "Should respect max limit");
    }

    function testFindFacetPosition() public {
        // Get facet addresses
        address[] memory facetAddresses = loupeFacet.facetAddresses();
        assertTrue(facetAddresses.length > 0, "Should have at least one facet");
        
        // Use the loupe facet to find the facet address for a function selector
        address existingFacet = facetAddresses[0];
        bytes4[] memory selectors = loupeFacet.facetFunctionSelectors(existingFacet);
        assertTrue(selectors.length > 0, "Facet should have selectors");
        
        // Use the address to verify we can find it with facetAddress
        address foundFacet = loupeFacet.facetAddress(selectors[0]);
        assertEq(foundFacet, existingFacet, "Should find the correct facet");
        
        // Test non-existent facet address
        bytes4 nonExistentSelector = bytes4(keccak256("nonExistentFunction()"));
        address notFoundFacet = loupeFacet.facetAddress(nonExistentSelector);
        assertEq(notFoundFacet, address(0), "Non-existent selector should return zero address");
    }

    // DIAMOND CUT TESTS

    function testDiamondConstructor() public {
        // Test valid construction
        BTRDiamond newDiamond = new BTRDiamond(admin, address(new DiamondCutFacet()));
        assertTrue(address(newDiamond) != address(0), "Diamond not deployed");
    }

    function testAddFacet() public {
        DiamondCutFacet newFacet = new DiamondCutFacet();
        
        // Add a test function
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = TEST_FUNC_1;
        
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(newFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });
        
        vm.prank(admin);
        cutFacet.diamondCut(cuts, address(0), new bytes(0));
        
        // Verify it was added
        address facet = loupeFacet.facetAddress(TEST_FUNC_1);
        assertEq(facet, address(newFacet), "Function should be added to the facet");
    }

    function testRemoveFacet() public {
        // First add a test facet
        DiamondCutFacet testFacet = new DiamondCutFacet();
        
        bytes4[] memory addSelectors = new bytes4[](1);
        addSelectors[0] = TEST_FUNC_2;
        
        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](1);
        addCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(testFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: addSelectors
        });
        
        vm.prank(admin);
        cutFacet.diamondCut(addCuts, address(0), new bytes(0));
        
        // Now remove it
        IDiamondCut.FacetCut[] memory removeCuts = new IDiamondCut.FacetCut[](1);
        removeCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(0),
            action: IDiamondCut.FacetCutAction.Remove,
            functionSelectors: addSelectors
        });
        
        vm.prank(admin);
        cutFacet.diamondCut(removeCuts, address(0), new bytes(0));
        
        // Verify it was removed
        address facet = loupeFacet.facetAddress(TEST_FUNC_2);
        assertEq(facet, address(0), "Function should be removed");
    }

    function testReplaceFacet() public {
        // First add a test facet
        DiamondCutFacet firstFacet = new DiamondCutFacet();
        
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = TEST_FUNC_3;
        
        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](1);
        addCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(firstFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });
        
        vm.prank(admin);
        cutFacet.diamondCut(addCuts, address(0), new bytes(0));
        
        // Now replace it
        DiamondCutFacet secondFacet = new DiamondCutFacet();
        
        IDiamondCut.FacetCut[] memory replaceCuts = new IDiamondCut.FacetCut[](1);
        replaceCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(secondFacet),
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: selectors
        });
        
        vm.prank(admin);
        cutFacet.diamondCut(replaceCuts, address(0), new bytes(0));
        
        // Verify it was replaced
        address facet = loupeFacet.facetAddress(TEST_FUNC_3);
        assertEq(facet, address(secondFacet), "Function should be replaced");
    }

    // EDGE CASES AND ERROR TESTS

    function testUnauthorizedCut() public {
        // Try to cut as non-admin
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = TEST_FUNC_1;
        
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(new DiamondCutFacet()),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });
        
        vm.prank(address(0xdead)); // Non-admin address
        vm.expectRevert(abi.encodeWithSelector(Errors.Unauthorized.selector, ErrorType.ADDRESS));
        cutFacet.diamondCut(cuts, address(0), new bytes(0));
    }

    function testEmptyCut() public {
        // Test empty cut array (should revert)
        IDiamondCut.FacetCut[] memory emptyCuts = new IDiamondCut.FacetCut[](0);
        
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(Errors.NotFound.selector, ErrorType.ACTION));
        cutFacet.diamondCut(emptyCuts, address(0), new bytes(0));
    }

    function testInvalidFacetAddress() public {
        // Test with zero address for facet in Add action
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = TEST_FUNC_1;
        
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(0),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });
        
        vm.prank(admin);
        vm.expectRevert(Errors.ZeroAddress.selector);
        cutFacet.diamondCut(cuts, address(0), new bytes(0));
    }

    function testCannotRemoveImmutableFunctions() public {
        // Try to remove a function from the diamond itself
        DiamondCutFacet testFacet = new DiamondCutFacet();
        
        // First add a function
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = TEST_FUNC_3;
        
        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](1);
        addCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(testFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });
        
        vm.prank(admin);
        cutFacet.diamondCut(addCuts, address(0), new bytes(0));
        
        // Now try to remove it claiming it's on "address(this)"
        IDiamondCut.FacetCut[] memory removeCuts = new IDiamondCut.FacetCut[](1);
        removeCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(diamond),
            action: IDiamondCut.FacetCutAction.Remove,
            functionSelectors: selectors
        });
        
        vm.prank(admin);
        vm.expectRevert(Errors.ZeroAddress.selector);
        cutFacet.diamondCut(removeCuts, address(0), new bytes(0));
    }

    function testReentrancyProtection() public pure {
        // This test will be implemented later with proper mocking
        assertTrue(true, "This test will be implemented later");
    }

    function testInvalidAction() public {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = TEST_FUNC_1;
        
        // Create cut with valid action first
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(new DiamondCutFacet()),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });
        
        // Corrupt the action value in memory to simulate invalid action
        uint256 invalidAction = 99;
        assembly {
            // Get pointer to the cuts array in memory
            let cutsPtr := add(cuts, 32) // skip length prefix
            // Get pointer to the first cut struct
            let cutPtr := mload(cutsPtr)
            // Get pointer to the action field (after facetAddress and functionSelectors)
            let actionPtr := add(cutPtr, 64)
            // Store invalid action value
            mstore(actionPtr, invalidAction)
        }
        
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(Errors.NotFound.selector, ErrorType.SELECTOR));
        cutFacet.diamondCut(cuts, address(0), new bytes(0));
    }

    function testFallbackFunction() public {
        // Test the diamond fallback function
        (bool success, ) = address(diamond).call(abi.encodeWithSelector(0x12345678));
        assertFalse(success, "Should revert for unknown function selector");
    }

    function testReceiveFunction() public {
        // Test the diamond receive function by sending ETH
        (bool success, ) = address(diamond).call{value: 1 ether}("");
        assertTrue(success, "Should accept ETH");
    }

    function testUpgradeCutFacet() public {
        // Get the current address of DiamondCutFacet
        bytes4 cutSelector = IDiamondCut.diamondCut.selector;
        address oldCutFacet = loupeFacet.facetAddress(cutSelector);
        
        // Deploy a new DiamondCutFacet
        DiamondCutFacet newCutFacet = new DiamondCutFacet();
        
        // Replace the existing facet with the new one
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = cutSelector;
        
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(newCutFacet),
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: selectors
        });
        
        vm.prank(admin);
        cutFacet.diamondCut(cuts, address(0), new bytes(0));
        
        // Verify the upgrade
        address newFacetAddress = loupeFacet.facetAddress(cutSelector);
        assertEq(newFacetAddress, address(newCutFacet), "DiamondCutFacet should be upgraded");
        assertNotEq(newFacetAddress, oldCutFacet, "New facet address should be different");
    }

    function testUpgradeLoupeFacet() public {
        // Get the current address of DiamondLoupeFacet
        bytes4 loupeSelector = IDiamondLoupe.facetAddresses.selector;
        address oldLoupeFacet = loupeFacet.facetAddress(loupeSelector);
        
        // Deploy a new DiamondLoupeFacet
        DiamondLoupeFacet newLoupeFacet = new DiamondLoupeFacet();
        
        // Replace the existing facet with the new one
        bytes4[] memory selectors = loupeFacet.facetFunctionSelectors(oldLoupeFacet);
        
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(newLoupeFacet),
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: selectors
        });
        
        vm.prank(admin);
        cutFacet.diamondCut(cuts, address(0), new bytes(0));
        
        // Verify the upgrade
        address newFacetAddress = loupeFacet.facetAddress(loupeSelector);
        assertEq(newFacetAddress, address(newLoupeFacet), "DiamondLoupeFacet should be upgraded");
        assertNotEq(newFacetAddress, oldLoupeFacet, "New facet address should be different");
    }

    // PAGINATION AND INTERFACE TESTS

    function testComplexPagination() public {
        // Test pagination with all parameters
        address[] memory facets = loupeFacet.facetAddresses();
        
        // Test empty result case
        address[] memory emptyFacets = loupeFacet.facetAddressesPaginated(999, 5);
        assertEq(emptyFacets.length, 0, "Should return empty array for out of range offset");
        
        // Test partial result case
        if (facets.length > 2) {
            address[] memory partialFacets = loupeFacet.facetAddressesPaginated(facets.length - 2, 5);
            assertEq(partialFacets.length, 2, "Should return only available elements");
        }
        
        // Similarly test for facets pagination
        IDiamondLoupe.Facet[] memory emptyDetailedFacets = loupeFacet.facetsPaginated(999, 5);
        assertEq(emptyDetailedFacets.length, 0, "Should return empty array for out of range offset");
    }

    function testAdditionalInterfaceSupport() public {
        // Test all supported interfaces
        assertTrue(loupeFacet.supportsInterface(type(IDiamondCut).interfaceId), "Should support IDiamondCut");
        assertTrue(loupeFacet.supportsInterface(type(IDiamondLoupe).interfaceId), "Should support IDiamondLoupe");
        assertTrue(loupeFacet.supportsInterface(type(IERC165).interfaceId), "Should support IERC165");
        
        // Test non-supported interface
        bytes4 randomInterface = bytes4(keccak256("random()"));
        assertFalse(loupeFacet.supportsInterface(randomInterface), "Should not support random interface");
    }

    // INIT FUNCTIONALITY TESTS

    function testInitializationFailure() public {
        // Add a new facet
        DiamondCutFacet newFacet = new DiamondCutFacet();
        
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = TEST_FUNC_1;
        
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(newFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });
        
        // Create an initializer that will revert
        address initializer = address(new FailingInitializer());
        bytes memory initData = abi.encodeWithSelector(FailingInitializer.initialize.selector);
        
        vm.prank(admin);
        vm.expectRevert();  // Just expect any revert
        cutFacet.diamondCut(cuts, initializer, initData);
    }

    function testInvalidInitCalldata() public {
        // Test invalid initialization parameters
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = TEST_FUNC_3;
        
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(new DiamondCutFacet()),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });
        
        // Test init address with no calldata
        vm.prank(admin);
        vm.expectRevert(Errors.UnexpectedInput.selector);
        cutFacet.diamondCut(cuts, address(1), new bytes(0));
        
        // Test no init address but with calldata
        vm.prank(admin);
        vm.expectRevert(Errors.UnexpectedInput.selector);
        cutFacet.diamondCut(cuts, address(0), abi.encodeWithSignature("someFunction()"));
    }

    function testUnexpectedInitCases() public {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = TEST_FUNC_1;
        
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(new DiamondCutFacet()),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });
        
        // Test with non-contract initializer
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(Errors.NotFound.selector, ErrorType.FACET));
        cutFacet.diamondCut(cuts, address(0x1234), abi.encodeWithSignature("someFunction()"));
    }
    
    function testRemoveLastSelector() public {
        // Add a test facet with a single function
        DiamondCutFacet testFacet = new DiamondCutFacet();
        
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = TEST_FUNC_3;
        
        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](1);
        addCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(testFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });
        
        vm.prank(admin);
        cutFacet.diamondCut(addCuts, address(0), new bytes(0));
        
        // Verify it was added
        address facet = loupeFacet.facetAddress(TEST_FUNC_3);
        assertEq(facet, address(testFacet), "Function not added correctly");
        
        // Now remove it - this should remove the entire facet
        IDiamondCut.FacetCut[] memory removeCuts = new IDiamondCut.FacetCut[](1);
        removeCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(0),
            action: IDiamondCut.FacetCutAction.Remove,
            functionSelectors: selectors
        });
        
        vm.prank(admin);
        cutFacet.diamondCut(removeCuts, address(0), new bytes(0));
        
        // Verify it was removed
        facet = loupeFacet.facetAddress(TEST_FUNC_3);
        assertEq(facet, address(0), "Function not removed correctly");
        
        // Verify the facet is no longer in the list
        address[] memory facets = loupeFacet.facetAddresses();
        for (uint i = 0; i < facets.length; i++) {
            assertFalse(facets[i] == address(testFacet), "Facet should be removed completely");
        }
    }
    
    function testReplaceNonExistentFunction() public {
        // Try to replace a function that doesn't exist
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = bytes4(keccak256("nonExistentFunction()"));
        
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](1);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(new DiamondCutFacet()),
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: selectors
        });
        
        vm.prank(admin);
        vm.expectRevert(); // Will fail because the selector doesn't exist
        cutFacet.diamondCut(cuts, address(0), new bytes(0));
    }
    
    function testAddSameFunction() public {
        // Add a test function
        DiamondCutFacet testFacet = new DiamondCutFacet();
        
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = TEST_FUNC_3;
        
        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](1);
        addCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(testFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });
        
        vm.prank(admin);
        cutFacet.diamondCut(addCuts, address(0), new bytes(0));
        
        // Try to add it again to the same facet (should fail)
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(Errors.AlreadyExists.selector, ErrorType.FUNCTION));
        cutFacet.diamondCut(addCuts, address(0), new bytes(0));
    }
    
    function testReplaceSameFacet() public {
        // Add a test function
        DiamondCutFacet testFacet = new DiamondCutFacet();
        
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = TEST_FUNC_3;
        
        IDiamondCut.FacetCut[] memory addCuts = new IDiamondCut.FacetCut[](1);
        addCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(testFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors
        });
        
        vm.prank(admin);
        cutFacet.diamondCut(addCuts, address(0), new bytes(0));
        
        // Try to replace it with the same facet (should fail)
        IDiamondCut.FacetCut[] memory replaceCuts = new IDiamondCut.FacetCut[](1);
        replaceCuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(testFacet),
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: selectors
        });
        
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(Errors.AlreadyExists.selector, ErrorType.FACET));
        cutFacet.diamondCut(replaceCuts, address(0), new bytes(0));
    }

    function testMultipleFacetOperations() public {
        // Create multiple facets
        DiamondCutFacet facet1 = new DiamondCutFacet();
        DiamondCutFacet facet2 = new DiamondCutFacet();
        DiamondCutFacet facet3 = new DiamondCutFacet();
        
        // Create selectors for each
        bytes4[] memory selectors1 = new bytes4[](1);
        selectors1[0] = TEST_FUNC_1;
        
        bytes4[] memory selectors2 = new bytes4[](1);
        selectors2[0] = TEST_FUNC_2;
        
        bytes4[] memory selectors3 = new bytes4[](1);
        selectors3[0] = TEST_FUNC_3;
        
        // Create a single cut with multiple operations
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](3);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(facet1),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors1
        });
        
        cuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(facet2),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors2
        });
        
        cuts[2] = IDiamondCut.FacetCut({
            facetAddress: address(facet3),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: selectors3
        });
        
        // Execute the cut
        vm.prank(admin);
        cutFacet.diamondCut(cuts, address(0), new bytes(0));
        
        // Verify all functions were added
        assertEq(loupeFacet.facetAddress(TEST_FUNC_1), address(facet1), "Function 1 not added correctly");
        assertEq(loupeFacet.facetAddress(TEST_FUNC_2), address(facet2), "Function 2 not added correctly");
        assertEq(loupeFacet.facetAddress(TEST_FUNC_3), address(facet3), "Function 3 not added correctly");
        
        // Now create a cut with mixed operations (add, replace, remove)
        bytes4[] memory replacementSelectors = new bytes4[](1);
        replacementSelectors[0] = TEST_FUNC_1;
        
        bytes4[] memory removalSelectors = new bytes4[](1);
        removalSelectors[0] = TEST_FUNC_2;
        
        cuts = new IDiamondCut.FacetCut[](2);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(facet3), // Replace facet1 with facet3 for TEST_FUNC_1
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: replacementSelectors
        });
        
        cuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(0), // Remove TEST_FUNC_2
            action: IDiamondCut.FacetCutAction.Remove,
            functionSelectors: removalSelectors
        });
        
        // Execute the mixed cut
        vm.prank(admin);
        cutFacet.diamondCut(cuts, address(0), new bytes(0));
        
        // Verify changes
        assertEq(loupeFacet.facetAddress(TEST_FUNC_1), address(facet3), "Function 1 not replaced correctly");
        assertEq(loupeFacet.facetAddress(TEST_FUNC_2), address(0), "Function 2 not removed correctly");
        assertEq(loupeFacet.facetAddress(TEST_FUNC_3), address(facet3), "Function 3 should remain unchanged");
    }
}
