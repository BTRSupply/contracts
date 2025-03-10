// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {LibDiamond} from "../libraries/LibDiamond.sol";
import {IDiamondLoupe} from "../interfaces/IDiamondLoupe.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {BTRErrors as Errors, BTREvents as Events} from "../libraries/BTREvents.sol";
import {BTRStorage as S} from "../libraries/BTRStorage.sol";
import {DiamondStorage} from "../BTRTypes.sol";

/// @title Diamond Loupe Facet
/// @dev Provides functions for inspecting the diamond's facets and functions
contract DiamondLoupeFacet is IDiamondLoupe, IERC165 {
  /// @notice Gets all facets and their selectors
  /// @return facets_ Array of facet information
  function facets() external view override returns (Facet[] memory facets_) {
    DiamondStorage storage ds = S.diamond();
    uint256 facetCount = ds.facetAddresses.length;
    facets_ = new Facet[](facetCount);
    
    // For each facet, collect its function selectors
    for (uint256 i; i < facetCount; i++) {
      address currentFacet = ds.facetAddresses[i];
      facets_[i].facetAddress = currentFacet;
      
      // Collect all selectors for this facet
      bytes4[] memory selectors = new bytes4[](ds.selectors.length);
      uint256 selectorCount = 0;
      
      for (uint256 j; j < ds.selectors.length; j++) {
        bytes4 selector = ds.selectors[j];
        address selectorFacet = address(bytes20(ds.facetAddressAndSelectorPosition[selector]));
        
        if (selectorFacet == currentFacet) {
          selectors[selectorCount] = selector;
          selectorCount++;
        }
      }
      
      // Resize selectors array to exact size
      assembly {
        mstore(selectors, selectorCount)
      }
      
      facets_[i].functionSelectors = selectors;
    }
  }

  /// @notice Gets all function selectors supported by a specific facet
  /// @param _facet The facet address
  /// @return facetFunctionSelectors_ Array of function selectors
  function facetFunctionSelectors(address _facet) external view override returns (bytes4[] memory facetFunctionSelectors_) {
    DiamondStorage storage ds = S.diamond();
    
    // Count selectors for this facet
    uint256 selectorCount = 0;
    for (uint256 i; i < ds.selectors.length; i++) {
      bytes4 selector = ds.selectors[i];
      address selectorFacet = address(bytes20(ds.facetAddressAndSelectorPosition[selector]));
      
      if (selectorFacet == _facet) {
        selectorCount++;
      }
    }
    
    // Collect selectors
    facetFunctionSelectors_ = new bytes4[](selectorCount);
    uint256 index = 0;
    
    for (uint256 i; i < ds.selectors.length; i++) {
      bytes4 selector = ds.selectors[i];
      address selectorFacet = address(bytes20(ds.facetAddressAndSelectorPosition[selector]));
      
      if (selectorFacet == _facet) {
        facetFunctionSelectors_[index] = selector;
        index++;
      }
    }
  }

  /// @notice Get all facet addresses used by a diamond
  /// @return facetAddresses_
  function facetAddresses() external view override returns (address[] memory facetAddresses_) {
    DiamondStorage storage ds = S.diamond();
    facetAddresses_ = ds.facetAddresses;
  }

  /// @notice Gets the facet that supports the given selector
  /// @param _functionSelector The function selector
  /// @return facetAddress_ The facet address
  function facetAddress(bytes4 _functionSelector) external view override returns (address facetAddress_) {
    DiamondStorage storage ds = S.diamond();
    facetAddress_ = address(bytes20(ds.facetAddressAndSelectorPosition[_functionSelector]));
  }

  /// @notice Used to query if a contract implements an interface
  /// @param _interfaceId The interface identifier
  /// @return bool Whether the contract implements the interface
  function supportsInterface(bytes4 _interfaceId) external view override returns (bool) {
    DiamondStorage storage ds = S.diamond();
    return ds.supportedInterfaces[_interfaceId];
  }
} 