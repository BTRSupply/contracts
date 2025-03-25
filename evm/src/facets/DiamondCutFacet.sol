// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {LibDiamond as D} from "@libraries/LibDiamond.sol";
import {IDiamondCut} from "@interfaces/IDiamond.sol";
import {PermissionedFacet} from "@facets/abstract/PermissionedFacet.sol";
import {NonReentrantFacet} from "@facets/abstract/NonReentrantFacet.sol";
import {LibAccessControl as AC} from "@libraries/LibAccessControl.sol";
import {BTRErrors as Errors} from "@libraries/BTREvents.sol";
import {ErrorType} from "@/BTRTypes.sol";

/// @title DiamondCutFacet 
/// @dev External facet for diamond cut functionality
contract DiamondCutFacet is IDiamondCut, NonReentrantFacet {
    /// @notice Adds/replaces/removes functions and optionally executes a function with delegatecall
    /// @param _diamondCut Contains the facet addresses and function selectors
    /// @param _init The address of the contract or facet to execute _calldata
    /// @param _calldata A function call, including function selector and arguments
    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override nonReentrant {
        if (!AC.hasRole(AC.ADMIN_ROLE, msg.sender)) {
            revert Errors.Unauthorized(ErrorType.ADDRESS);
        }
        D.diamondCut(_diamondCut, _init, _calldata);
    }
}
