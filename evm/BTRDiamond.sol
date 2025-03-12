// evm/BTRDiamond.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {LibDiamond} from "./libraries/LibDiamond.sol";
import {LibAccessControl} from "./libraries/LibAccessControl.sol";
import {IDiamondCut} from "./interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "./interfaces/IDiamondLoupe.sol";
import {IERC173} from "./interfaces/IERC173.sol";
import {IERC165} from "@openzeppelin/interfaces/IERC165.sol";
import {BTRErrors as Errors, BTREvents as Events} from "./libraries/BTREvents.sol";
import {BTRStorage as S} from "./libraries/BTRStorage.sol";
import {DiamondStorage, AccessControlStorage, ErrorType} from "./BTRTypes.sol";
import {EnumerableSet} from "@openzeppelin/utils/structs/EnumerableSet.sol";

/// @title BTR Diamond Contract
/// @dev Implementation of the Diamond Pattern (EIP-2535)
contract BTRDiamond {
  using EnumerableSet for EnumerableSet.AddressSet;

  constructor(address _owner, address _diamondCutFacet) payable {
    if (_owner == address(0)) revert Errors.ZeroAddress();
    if (_diamondCutFacet == address(0)) revert Errors.NotFound(ErrorType.FACET);

    // Initialize diamond storage
    DiamondStorage storage ds = S.diamond();
    
    // Initialize access control directly from BTRStorage
    AccessControlStorage storage acs = S.accessControl();
    
    // Set up ADMIN_ROLE and ADMIN_ROLE for ownership management
    acs.roles[LibAccessControl.ADMIN_ROLE].members.add(_owner);
    acs.roles[LibAccessControl.ADMIN_ROLE].members.add(_owner);
    
    // Configure admin role hierarchy
    acs.roles[LibAccessControl.ADMIN_ROLE].adminRole = LibAccessControl.ADMIN_ROLE;
    
    // Add diamondCut function
    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = IDiamondCut.diamondCut.selector;
    
    // Add DiamondCutFacet
    LibDiamond.addFunctions(_diamondCutFacet, selectors);

    // Initialize supported interfaces
    ds.supportedInterfaces[type(IERC165).interfaceId] = true;
    ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
    ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
    ds.supportedInterfaces[type(IERC173).interfaceId] = true;
  }

  // Find facet for function that is called and execute the
  // function if a facet is found and return any value.
  fallback() external payable {
    DiamondStorage storage ds = S.diamond();
    
    // Get facet from function selector
    address facet = address(bytes20(ds.facetAddressAndSelectorPosition[msg.sig]));
    if (facet == address(0)) revert Errors.NotFound(ErrorType.FUNCTION);
    
    // Execute external function from facet using delegatecall and return any value
    assembly {
      // Copy function selector and any arguments
      calldatacopy(0, 0, calldatasize())
      // Execute function call using the facet
      let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
      // Get any return value
      returndatacopy(0, 0, returndatasize())
      // Return any return value or error back to the caller
      switch result
        case 0 {revert(0, returndatasize())}
        default {return (0, returndatasize())}
    }
  }

  receive() external payable {
    revert Errors.Unauthorized(ErrorType.FUNCTION);
  }
}
