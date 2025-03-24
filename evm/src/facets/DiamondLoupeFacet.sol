// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {LibDiamond} from "@libraries/LibDiamond.sol";
import {IDiamondLoupe} from "@interfaces/IDiamondLoupe.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {BTRErrors as Errors, BTREvents as Events} from "@libraries/BTREvents.sol";
import {BTRStorage as S} from "@libraries/BTRStorage.sol";
import {Diamond, ErrorType} from "@/BTRTypes.sol";

/// @title Diamond Loupe Facet
/// @dev Provides functions for inspecting the diamond's facets and functions
contract DiamondLoupeFacet is IDiamondLoupe, IERC165 {

  /// @notice Gets all facets and their selectors
  /// @return facets_ Array of facet information
  function facets() external view override returns (Facet[] memory facets_) {
    return facetsPaginated(0, type(uint256).max);
  }

  /// @notice Gets all facets and their selectors with pagination support
  /// @param _start The starting index in the facets array
  /// @param _count The maximum number of facets to return
  /// @return facets_ Array of facet information
  function facetsPaginated(uint256 _start, uint256 _count) public view returns (Facet[] memory facets_) {
    Diamond storage ds = S.diamond();
    uint256 numFacets = ds.facetAddresses.length;
    
    // Handle out-of-bounds start index
    if (_start >= numFacets) {
      return new Facet[](0);
    }
    
    // Calculate the actual range to return
    uint256 end = _start + _count;
    if (end > numFacets) {
      end = numFacets;
    }
    uint256 resultCount = end - _start;
    
    facets_ = new Facet[](resultCount);
    
    for (uint256 i = 0; i < resultCount; ) {
      address facetAddr = ds.facetAddresses[_start + i];
      facets_[i].facetAddress = facetAddr;
      facets_[i].functionSelectors = ds.facetFunctionSelectors[facetAddr].functionSelectors;
      unchecked { ++i; }
    }
  }

  /// @notice Gets all function selectors supported by a specific facet
  /// @param _facet The facet address
  /// @return facetFunctionSelectors_ Array of function selectors
  function facetFunctionSelectors(address _facet) external view override returns (bytes4[] memory facetFunctionSelectors_) {
    Diamond storage ds = S.diamond();
    facetFunctionSelectors_ = ds.facetFunctionSelectors[_facet].functionSelectors;
  }

  /// @notice Gets all function selectors for a facet with pagination
  /// @param _facet The facet address
  /// @param _start The starting index
  /// @param _count The maximum number of selectors to return
  /// @return selectors_ Array of function selectors
  function facetFunctionSelectorsPaginated(address _facet, uint256 _start, uint256 _count) 
    public view returns (bytes4[] memory selectors_) 
  {
    Diamond storage ds = S.diamond();
    bytes4[] memory allSelectors = ds.facetFunctionSelectors[_facet].functionSelectors;
    uint256 selectorsCount = allSelectors.length;
    
    // Handle out-of-bounds start index
    if (_start >= selectorsCount) {
      return new bytes4[](0);
    }
    
    // Calculate the actual range to return
    uint256 end = _start + _count;
    if (end > selectorsCount) {
      end = selectorsCount;
    }
    uint256 resultCount = end - _start;
    
    selectors_ = new bytes4[](resultCount);
    
    for (uint256 i = 0; i < resultCount; ) {
      selectors_[i] = allSelectors[_start + i];
      unchecked { ++i; }
    }
  }

  /// @notice Gets all facet addresses used by the diamond
  /// @return facetAddresses_ Array of facet addresses
  function facetAddresses() external view override returns (address[] memory facetAddresses_) {
    Diamond storage ds = S.diamond();
    facetAddresses_ = ds.facetAddresses;
  }
  
  /// @notice Gets facet addresses with pagination
  /// @param _start The starting index
  /// @param _count The maximum number of addresses to return
  /// @return addresses_ Array of facet addresses
  function facetAddressesPaginated(uint256 _start, uint256 _count) 
    public view returns (address[] memory addresses_) 
  {
    Diamond storage ds = S.diamond();
    uint256 addressesCount = ds.facetAddresses.length;
    
    // Handle out-of-bounds start index
    if (_start >= addressesCount) {
      return new address[](0);
    }
    
    // Calculate the actual range to return
    uint256 end = _start + _count;
    if (end > addressesCount) {
      end = addressesCount;
    }
    uint256 resultCount = end - _start;
    
    addresses_ = new address[](resultCount);
    
    for (uint256 i = 0; i < resultCount; ) {
      addresses_[i] = ds.facetAddresses[_start + i];
      unchecked { ++i; }
    }
  }

  /// @notice Gets the facet address that supports the given selector
  /// @param _functionSelector The function selector
  /// @return facetAddress_ The facet address
  function facetAddress(bytes4 _functionSelector) external view override returns (address facetAddress_) {
    Diamond storage ds = S.diamond();
    facetAddress_ = ds.selectorToFacetAndPosition[_functionSelector].facetAddress;
  }

  /// @notice Implements ERC-165 interface detection standard
  /// @param _interfaceId The interface id to check
  /// @return bool Whether the contract implements the interface
  function supportsInterface(bytes4 _interfaceId) external view override returns (bool) {
    Diamond storage ds = S.diamond();
    return ds.supportedInterfaces[_interfaceId] ||
        _interfaceId == type(IERC165).interfaceId ||
        _interfaceId == type(IDiamondLoupe).interfaceId ||
        _interfaceId == type(IERC721Receiver).interfaceId || // rescuable
        _interfaceId == type(IERC1155Receiver).interfaceId; // rescuable
  }
}
