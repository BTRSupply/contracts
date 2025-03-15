// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IDiamondCut} from "@interfaces/IDiamondCut.sol";
import {BTRStorage as S} from "@libraries/BTRStorage.sol";
import {Diamond, FacetAddressAndPosition, FacetFunctionSelectors, ErrorType} from "@/BTRTypes.sol";
import {LibAccessControl as AC} from "@libraries/LibAccessControl.sol";
import {BTRErrors as Errors, BTREvents as Events} from "@libraries/BTREvents.sol";

/// Implementation of EIP-2535 Diamond Standard
/// https://eips.ethereum.org/EIPS/eip-2535
library LibDiamond {

    /// @notice Get the contract admin (first ADMIN_ROLE holder)
    /// @return Address of the first admin
    function owner() internal view returns (address) {
        return AC.admin();
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

    // Internal function version of diamondCut with reentrancy protection
    function diamondCut(
        IDiamondCut.FacetCut[] memory _diamondCut,
        address _init,
        bytes memory _calldata
    ) internal {
        Diamond storage ds = S.diamond();
        
        // Prevent reentrancy during diamond cut operations
        if (ds.cutting) revert Errors.Locked();
        ds.cutting = true;
        
        // Validate diamond cut is not empty
        if (_diamondCut.length == 0) {
            revert Errors.NotFound(ErrorType.ACTION);
        }
        
        for (uint256 facetIndex; facetIndex < _diamondCut.length; ) {
            IDiamondCut.FacetCutAction action = _diamondCut[facetIndex].action;
            if (action == IDiamondCut.FacetCutAction.Add) {
                addFunctions(_diamondCut[facetIndex].facetAddress, _diamondCut[facetIndex].functionSelectors);
            } else if (action == IDiamondCut.FacetCutAction.Replace) {
                replaceFunctions(_diamondCut[facetIndex].facetAddress, _diamondCut[facetIndex].functionSelectors);
            } else if (action == IDiamondCut.FacetCutAction.Remove) {
                removeFunctions(_diamondCut[facetIndex].facetAddress, _diamondCut[facetIndex].functionSelectors);
            } else {
                revert Errors.NotFound(ErrorType.ACTION);
            }
            unchecked {
                ++facetIndex;
            }
        }
        emit Events.DiamondCut(_diamondCut, _init, _calldata);
        initializeDiamondCut(_init, _calldata);

        // Reset reentrancy guard
        ds.cutting = false;
    }

    function addFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        if (_functionSelectors.length == 0) {
            revert Errors.NotFound(ErrorType.SELECTOR);
        }
        Diamond storage ds = S.diamond();
        if (_facetAddress == address(0)) {
            revert Errors.ZeroAddress();
        }
        uint96 selectorPosition = uint96(ds.facetFunctionSelectors[_facetAddress].functionSelectors.length);
        // add new facet address if it does not exist
        if (selectorPosition == 0) {
            addFacet(ds, _facetAddress);
        }
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; ) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = ds.selectorToFacetAndPosition[selector].facetAddress;
            if (oldFacetAddress != address(0)) {
                revert Errors.AlreadyExists(ErrorType.FUNCTION);
            }
            addFunction(ds, selector, selectorPosition, _facetAddress);
            emit Events.FunctionAdded(_facetAddress, selector);
            unchecked {
                ++selectorPosition;
                ++selectorIndex;
            }
        }
    }

    function replaceFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        if (_functionSelectors.length == 0) {
            revert Errors.NotFound(ErrorType.SELECTOR);
        }
        Diamond storage ds = S.diamond();
        if (_facetAddress == address(0)) {
            revert Errors.ZeroAddress();
        }
        uint96 selectorPosition = uint96(ds.facetFunctionSelectors[_facetAddress].functionSelectors.length);
        // add new facet address if it does not exist
        if (selectorPosition == 0) {
            addFacet(ds, _facetAddress);
        }
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; ) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = ds.selectorToFacetAndPosition[selector].facetAddress;
            if (oldFacetAddress == _facetAddress) {
                revert Errors.AlreadyExists(ErrorType.FACET);
            }
            removeFunction(ds, oldFacetAddress, selector);
            addFunction(ds, selector, selectorPosition, _facetAddress);
            emit Events.FunctionReplaced(oldFacetAddress, _facetAddress, selector);
            unchecked {
                ++selectorPosition;
                ++selectorIndex;
            }
        }
    }

    function removeFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        if (_functionSelectors.length == 0) {
            revert Errors.NotFound(ErrorType.SELECTOR);
        }
        
        Diamond storage ds = S.diamond();
        // For removeFunctions, the facet address should be zero
        // as we identify facets by their selector and don't need the address
        if (_facetAddress != address(0)) {
            revert Errors.ZeroAddress();
        }
        
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; ) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = ds.selectorToFacetAndPosition[selector].facetAddress;
            
            removeFunction(ds, oldFacetAddress, selector);
            unchecked {
                ++selectorIndex;
            }
        }
    }

    function addFacet(Diamond storage ds, address _facetAddress) internal {
        enforceHasContractCode(_facetAddress);
        ds.facetFunctionSelectors[_facetAddress].facetAddressPosition = ds.facetAddresses.length;
        ds.facetAddresses.push(_facetAddress);
        emit Events.FacetAdded(_facetAddress);
    }

    function addFunction(
        Diamond storage ds,
        bytes4 _selector,
        uint96 _selectorPosition,
        address _facetAddress
    ) internal {
        ds.selectorToFacetAndPosition[_selector].functionSelectorPosition = _selectorPosition;
        ds.facetFunctionSelectors[_facetAddress].functionSelectors.push(_selector);
        ds.selectorToFacetAndPosition[_selector].facetAddress = _facetAddress;
    }

    function removeFunction(
        Diamond storage ds,
        address _facetAddress,
        bytes4 _selector
    ) internal {
        if (_facetAddress == address(0)) {
            revert Errors.ZeroAddress();
        }
        // an immutable function is a function defined directly in a diamond
        if (_facetAddress == address(this)) {
            revert Errors.Unauthorized(ErrorType.ACTION); // immutable facet: diamond proxy itself
        }
        // replace selector with last selector, then delete last selector
        uint256 selectorPosition = ds.selectorToFacetAndPosition[_selector].functionSelectorPosition;
        uint256 lastSelectorPosition = ds.facetFunctionSelectors[_facetAddress].functionSelectors.length - 1;
        // if not the same then replace _selector with lastSelector
        if (selectorPosition != lastSelectorPosition) {
            bytes4 lastSelector = ds.facetFunctionSelectors[_facetAddress].functionSelectors[lastSelectorPosition];
            ds.facetFunctionSelectors[_facetAddress].functionSelectors[selectorPosition] = lastSelector;
            ds.selectorToFacetAndPosition[lastSelector].functionSelectorPosition = uint96(selectorPosition);
        }
        // delete the last selector
        ds.facetFunctionSelectors[_facetAddress].functionSelectors.pop();
        delete ds.selectorToFacetAndPosition[_selector];
        emit Events.FunctionRemoved(_facetAddress, _selector);

        // if no more selectors for facet address then delete the facet address
        if (lastSelectorPosition == 0) {
            // replace facet address with last facet address and delete last facet address
            uint256 lastFacetAddressPosition = ds.facetAddresses.length - 1;
            uint256 facetAddressPosition = ds.facetFunctionSelectors[_facetAddress].facetAddressPosition;
            if (facetAddressPosition != lastFacetAddressPosition) {
                address lastFacetAddress = ds.facetAddresses[lastFacetAddressPosition];
                ds.facetAddresses[facetAddressPosition] = lastFacetAddress;
                ds.facetFunctionSelectors[lastFacetAddress].facetAddressPosition = facetAddressPosition;
            }
            ds.facetAddresses.pop();
            delete ds.facetFunctionSelectors[_facetAddress].facetAddressPosition;
            emit Events.FacetRemoved(_facetAddress);
        }
    }

    function initializeDiamondCut(address _init, bytes memory _calldata) internal {
        // Reentrancy protection for initialization is already covered by ds.cutting
        // which is set in the diamondCut function and prevents reentry
        
        if (_init == address(0)) {
            if (_calldata.length != 0) {
                revert Errors.UnexpectedInput();
            }
        } else {
            if (_calldata.length == 0) {
                revert Errors.UnexpectedInput();
            }
            if (_init != address(this)) {
                enforceHasContractCode(_init);
            }
            (bool success, bytes memory error) = _init.delegatecall(_calldata);
            if (!success) {
                emit Events.InitializationFailed(_init, error);
                if (error.length > 0) {
                    // bubble up the error
                    revert(string(error));
                } else {
                    revert Errors.InitializationFailed();
                }
            }
        }
    }
    
    /// @notice Finds a facet's position or determines it doesn't exist
    /// @param _facetAddress The facet address to find
    /// @param ds The diamond storage reference
    /// @return exists Whether the facet exists
    /// @return position The position of the facet if exists, otherwise 0
    function findFacetPosition(address _facetAddress, Diamond storage ds) 
        internal view 
        returns (bool exists, uint256 position) 
    {
        // More efficient implementation using the facetAddressPosition mapping
        position = ds.facetFunctionSelectors[_facetAddress].facetAddressPosition;
        
        // Check if the position is valid (facet exists)
        if (position < ds.facetAddresses.length && ds.facetAddresses[position] == _facetAddress) {
            return (true, position);
        }
        
        return (false, 0);
    }
}
