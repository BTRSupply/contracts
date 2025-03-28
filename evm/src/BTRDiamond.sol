// SPDX-License-Identifier: MIT
/**
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@@@@@/         '@@@@/            /@@@/         '@@@@@@@@
@@@@@@@@/    /@@@    @@@@@@/    /@@@@@@@/    /@@@    @@@@@@@
@@@@@@@/           _@@@@@@/    /@@@@@@@/    /.     _@@@@@@@@
@@@@@@/    /@@@    '@@@@@/    /@@@@@@@/    /@@    @@@@@@@@@@
@@@@@/            ,@@@@@/    /@@@@@@@/    /@@@,    @@@@@@@@@
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
 *
 * @title BTRDiamond - Implementation of the Diamond Pattern (EIP-2535)
 * @notice The Diamond Pattern is used to manage BTR protocol's code
 * @dev Implements facets and function selectors as per EIP-2535
 * @author BTR Team
 */

pragma solidity 0.8.28;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IDiamondCut, IDiamondLoupe, IDiamond} from "@interfaces/IDiamond.sol";
import {LibAccessControl as AC} from "@libraries/LibAccessControl.sol";
import {LibDiamond as D} from "@libraries/LibDiamond.sol";
import {AccessControl, Diamond, ErrorType} from "@/BTRTypes.sol";
import {BTRErrors as Errors} from "@libraries/BTREvents.sol";
import {BTREvents as Events} from "@libraries/BTREvents.sol";
import {BTRStorage as S} from "@libraries/BTRStorage.sol";

contract BTRDiamond is IDiamond {
    using EnumerableSet for EnumerableSet.AddressSet;

    constructor(address _owner, address _treasury, address _diamondCutFacet) payable {
        if (_owner == address(0)) revert Errors.ZeroAddress();
        if (_treasury == address(0)) revert Errors.ZeroAddress();
        if (_diamondCutFacet == address(0))
            revert Errors.NotFound(ErrorType.FACET);
        
        D.enforceHasContractCode(_diamondCutFacet);
        AccessControl storage acs = S.accessControl();
        
        // Set timelock configuration
        acs.grantDelay = AC.DEFAULT_GRANT_DELAY;
        acs.acceptWindow = AC.DEFAULT_ACCEPT_WINDOW;

        // Initialize admin role 
        // For initial setup, we directly grant and accept to avoid timelock issues
        acs.roles[AC.ADMIN_ROLE].adminRole = AC.ADMIN_ROLE;
        acs.roles[AC.ADMIN_ROLE].members.add(_owner);
        emit Events.RoleGranted(AC.ADMIN_ROLE, _owner, address(this));
        emit Events.OwnershipTransferred(address(this), _owner);
        
        // Set up roles with the admin role as their admin
        acs.roles[AC.MANAGER_ROLE].adminRole = AC.ADMIN_ROLE;
        acs.roles[AC.MANAGER_ROLE].members.add(_owner);
        emit Events.RoleGranted(AC.MANAGER_ROLE, _owner, address(this));
        
        acs.roles[AC.KEEPER_ROLE].adminRole = AC.ADMIN_ROLE;
        
        acs.roles[AC.TREASURY_ROLE].adminRole = AC.ADMIN_ROLE;
        acs.roles[AC.TREASURY_ROLE].members.add(_treasury);
        emit Events.RoleGranted(AC.TREASURY_ROLE, _treasury, address(this));
        
        // Set treasury address
        S.core().treasury.treasury = _treasury;
        
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = IDiamondCut.diamondCut.selector;
        cut[0] = IDiamondCut.FacetCut({
            facetAddress: _diamondCutFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });
        D.diamondCut(cut, address(0), "");
        Diamond storage ds = S.diamond();
        ds.supportedInterfaces[type(IERC165).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
    }

    fallback() external payable {
        Diamond storage ds = S.diamond();
        address facet = ds.selectorToFacetAndPosition[msg.sig].facetAddress;
        if (facet == address(0)) revert Errors.NotFound(ErrorType.FUNCTION);
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }
    receive() external payable {} // Receive function to allow contract to receive ETH
}
