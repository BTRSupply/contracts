// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IDiamondCut} from "../interfaces/IDiamondCut.sol";
import {BTRStorage as S} from "./BTRStorage.sol";
import {DiamondStorage} from "../BTRTypes.sol";
import {ErrorType} from "../BTRTypes.sol";
import {LibAccessControl} from "./LibAccessControl.sol";
import {BTRErrors as Errors, BTREvents as Events} from "./BTREvents.sol";

library LibDiamond {
    struct FacetAddressAndPosition {
        address facetAddress;
        uint16 functionSelectorPosition; // position in functionSelectors array
    }

    // Events
    event DiamondCut(IDiamondCut.FacetCut[] _diamondCut, address _init, bytes _calldata);

    /// @notice Get the contract admin (first ADMIN_ROLE holder)
    /// @return Address of the first admin
    function contractOwner() internal view returns (address) {
        // Get admin role members
        address[] memory admins = LibAccessControl.getMembers(LibAccessControl.ADMIN_ROLE);
        return admins.length > 0 ? admins[0] : address(0);
    }

    /// @notice Set a new admin (replaces setContractOwner)
    /// @dev Creates a role acceptance for the new admin
    /// @param _newOwner New admin address
    function setContractOwner(address _newOwner) internal {
        // We'll emit the ownership transfer event to maintain compatibility
        address previousOwner = contractOwner();
        
        // Set up pending acceptance for admin role
        LibAccessControl.createRoleAcceptance(
            LibAccessControl.ADMIN_ROLE, 
            _newOwner, 
            previousOwner
        );
    }

    /// @notice Verify that an address contains contract code
    /// @param _contract Address to check
    function enforceHasContractCode(address _contract) internal view {
        uint256 contractSize;
        assembly {
            contractSize := extcodesize(_contract)
        }
        if(contractSize == 0) {
            revert Errors.NotFound(ErrorType.FACET);
        }
    }

    // Internal function version of diamondCut
    function diamondCut(
        IDiamondCut.FacetCut[] memory _diamondCut,
        address _init,
        bytes memory _calldata
    ) internal {
        uint256 cutLength = _diamondCut.length;
        for (uint256 facetIndex; facetIndex < cutLength;) {
            IDiamondCut.FacetCutAction action = _diamondCut[facetIndex].action;
            
            if (action == IDiamondCut.FacetCutAction.Add) {
                addFunctions(
                    _diamondCut[facetIndex].facetAddress, 
                    _diamondCut[facetIndex].functionSelectors
                );
            } else if (action == IDiamondCut.FacetCutAction.Replace) {
                replaceFunctions(
                    _diamondCut[facetIndex].facetAddress, 
                    _diamondCut[facetIndex].functionSelectors
                );
            } else if (action == IDiamondCut.FacetCutAction.Remove) {
                removeFunctions(
                    _diamondCut[facetIndex].facetAddress, 
                    _diamondCut[facetIndex].functionSelectors
                );
            } else {
                revert Errors.NotFound(ErrorType.ACTION);
            }
            
            unchecked { ++facetIndex; }
        }
        emit DiamondCut(_diamondCut, _init, _calldata);
        initializeDiamondCut(_init, _calldata);
    }

    function addFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        if (_functionSelectors.length == 0) {
            revert Errors.NotFound(ErrorType.SELECTOR);
        }
        if (_facetAddress == address(0)) {
            revert Errors.ZeroAddress();
        }
        
        // Verify the facet has code
        enforceHasContractCode(_facetAddress);
        
        DiamondStorage storage ds = S.diamond();
        uint256 selectorsLength = _functionSelectors.length;
        
        // Check if facet address already exists
        (bool facetExists, ) = findFacetPosition(_facetAddress, ds);
        
        // Add new facet address if it doesn't exist
        if (!facetExists) {
            ds.facetAddresses.push(_facetAddress);
            ds.facetAddressPosition[_facetAddress] = ds.facetAddresses.length - 1;
        }
        
        for (uint256 selectorIndex; selectorIndex < selectorsLength;) {
            bytes4 selector = _functionSelectors[selectorIndex];
            bytes32 oldFacetAndPosition = ds.facetAddressAndSelectorPosition[selector];
            address oldFacetAddress = address(bytes20(oldFacetAndPosition));
            
            if (oldFacetAddress != address(0)) {
                revert Errors.AlreadyExists(ErrorType.FUNCTION);
            }
            
            // Add selector with position at the end of the selectors array
            uint256 selectorPosition = ds.selectors.length;
            ds.facetAddressAndSelectorPosition[selector] = bytes32(uint256(uint160(_facetAddress))) | bytes32(uint256(selectorPosition) << 160);
            
            // Add selector to array
            ds.selectors.push(selector);
            
            unchecked { ++selectorIndex; }
        }
    }

    function replaceFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        if (_functionSelectors.length == 0) {
            revert Errors.NotFound(ErrorType.SELECTOR);
        }
        if (_facetAddress == address(0)) {
            revert Errors.ZeroAddress();
        }
        
        // Verify the facet has code
        enforceHasContractCode(_facetAddress);
        
        DiamondStorage storage ds = S.diamond();
        uint256 selectorsLength = _functionSelectors.length;
        
        // Check if facet address already exists
        (bool facetExists, ) = findFacetPosition(_facetAddress, ds);
        
        // Add new facet address if it doesn't exist
        if (!facetExists) {
            ds.facetAddresses.push(_facetAddress);
            ds.facetAddressPosition[_facetAddress] = ds.facetAddresses.length - 1;
        }
        
        for (uint256 selectorIndex; selectorIndex < selectorsLength;) {
            bytes4 selector = _functionSelectors[selectorIndex];
            bytes32 oldFacetAndPosition = ds.facetAddressAndSelectorPosition[selector];
            address oldFacetAddress = address(bytes20(oldFacetAndPosition));
            
            if (oldFacetAddress == address(0)) {
                revert Errors.NotFound(ErrorType.FUNCTION);
            }
            if (oldFacetAddress == _facetAddress) {
                revert Errors.AlreadyExists(ErrorType.FACET);
            }
            
            // Keep the same position, just update facet address
            uint256 selectorPosition = uint256(uint16(uint256(oldFacetAndPosition) >> 160));
            ds.facetAddressAndSelectorPosition[selector] = bytes32(uint256(uint160(_facetAddress))) | bytes32(selectorPosition << 160);
            
            unchecked { ++selectorIndex; }
        }
    }

    function removeFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        if (_functionSelectors.length == 0) {
            revert Errors.NotFound(ErrorType.SELECTOR);
        }
        
        DiamondStorage storage ds = S.diamond();
        bool checkFacetAddress = _facetAddress != address(0);
        uint256 selectorsLength = _functionSelectors.length;
        
        for (uint256 selectorIndex; selectorIndex < selectorsLength;) {
            bytes4 selector = _functionSelectors[selectorIndex];
            bytes32 oldFacetAndPosition = ds.facetAddressAndSelectorPosition[selector];
            address oldFacetAddress = address(bytes20(oldFacetAndPosition));
            
            if (oldFacetAddress == address(0)) {
                revert Errors.NotFound(ErrorType.FUNCTION);
            }
            if (checkFacetAddress && oldFacetAddress != _facetAddress) {
                revert Errors.NotFound(ErrorType.FACET);
            }
            
            // Get position in the selectors array
            uint256 selectorPosition = uint256(uint16(uint256(oldFacetAndPosition) >> 160));
            
            // If not the last selector, replace with the last one
            if (selectorPosition != ds.selectors.length - 1) {
                // Replace with the last selector
                bytes4 lastSelector = ds.selectors[ds.selectors.length - 1];
                ds.selectors[selectorPosition] = lastSelector;
                
                // Update position of the moved selector
                bytes32 lastSelectorFacetAndPosition = ds.facetAddressAndSelectorPosition[lastSelector];
                address lastSelectorFacet = address(bytes20(lastSelectorFacetAndPosition));
                
                // Update the mapping with the new position
                ds.facetAddressAndSelectorPosition[lastSelector] = bytes32(uint256(uint160(lastSelectorFacet))) | bytes32(selectorPosition << 160);
            }
            
            // Delete the selector mapping and remove the last selector
            delete ds.facetAddressAndSelectorPosition[selector];
            ds.selectors.pop();
            
            // Check if this was the last selector for the facet
            bool lastSelectorForFacet = true;
            for (uint256 i; i < ds.selectors.length;) {
                bytes4 otherSelector = ds.selectors[i];
                address otherFacetAddress = address(bytes20(ds.facetAddressAndSelectorPosition[otherSelector]));
                
                if (otherFacetAddress == oldFacetAddress) {
                    lastSelectorForFacet = false;
                    break;
                }
                
                unchecked { ++i; }
            }
            
            // If this was the last selector for the facet, remove facet address
            if (lastSelectorForFacet) {
                uint256 lastFacetIndex = ds.facetAddresses.length - 1;
                uint256 facetIndex = ds.facetAddressPosition[oldFacetAddress];
                
                // If not the last facet address, swap with the last one
                if (facetIndex != lastFacetIndex) {
                    address lastFacetAddress = ds.facetAddresses[lastFacetIndex];
                    ds.facetAddresses[facetIndex] = lastFacetAddress;
                    ds.facetAddressPosition[lastFacetAddress] = facetIndex;
                }
                
                // Remove the last facet address
                ds.facetAddresses.pop();
                delete ds.facetAddressPosition[oldFacetAddress];
            }
            
            unchecked { ++selectorIndex; }
        }
    }

    function initializeDiamondCut(address _init, bytes memory _calldata) internal {
        if (_init == address(0)) {
            return;
        }
        
        // Verify the init contract has code
        enforceHasContractCode(_init);
        
        (bool success, bytes memory error) = _init.delegatecall(_calldata);
        if (!success) {
            if (error.length > 0) {
                // Bubble up the error
                assembly {
                    let returndata_size := mload(error)
                    revert(add(32, error), returndata_size)
                }
            } else {
                revert Errors.Failed(ErrorType.FUNCTION);
            }
        }
    }
    
    /// @notice Finds a facet's position or determines it doesn't exist
    /// @param _facetAddress The facet address to find
    /// @param ds The diamond storage reference
    /// @return exists Whether the facet exists
    /// @return position The position of the facet if exists, otherwise 0
    function findFacetPosition(address _facetAddress, DiamondStorage storage ds) 
        internal view 
        returns (bool exists, uint256 position) 
    {
        uint256 facetsLength = ds.facetAddresses.length;
        
        for (uint256 i; i < facetsLength;) {
            if (ds.facetAddresses[i] == _facetAddress) {
                return (true, i);
            }
            unchecked { ++i; }
        }
        
        return (false, 0);
    }
}
