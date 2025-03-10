// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {BTRDiamond} from "../BTRDiamond.sol";
import {DiamondCutFacet} from "../facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../facets/DiamondLoupeFacet.sol";
import {AccessControlFacet} from "../facets/AccessControlFacet.sol";
import {IDiamondCut} from "../interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../interfaces/IDiamondLoupe.sol";
import {IERC173} from "../interfaces/IERC173.sol";
import {IERC165} from "@openzeppelin/interfaces/IERC165.sol";
import {PermissionedFacet} from "../facets/abstract/PermissionedFacet.sol";

// Diamond initializer contract
contract DiamondInit {
    /// @notice Initialize the diamond with initial settings
    /// @param _admin Admin address
    function init(address _admin) external {
        // Initialize the access control
        AccessControlFacet(address(this)).initialize(_admin);
    }
}

contract DiamondDeployer {
    struct Deployment {
        BTRDiamond diamond;
        DiamondCutFacet diamondCutFacet;
        DiamondLoupeFacet diamondLoupeFacet;
        AccessControlFacet accessControlFacet;
        DiamondInit diamondInit;
    }

    function deployDiamond(address admin) external returns (Deployment memory) {
        // Deploy facets
        DiamondCutFacet diamondCutFacet = new DiamondCutFacet();
        DiamondLoupeFacet diamondLoupeFacet = new DiamondLoupeFacet();
        AccessControlFacet accessControlFacet = new AccessControlFacet();
        DiamondInit diamondInit = new DiamondInit();

        // Deploy diamond
        BTRDiamond diamond = new BTRDiamond(admin, address(diamondCutFacet));

        // Prepare facet cuts
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](2);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(diamondLoupeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: generateDiamondLoupeSelectors()
        });
        cuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(accessControlFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: generateAccessControlSelectors()
        });

        // Execute diamond cut and initialize
        bytes memory calldata_ = abi.encodeWithSelector(DiamondInit.init.selector, admin);
        IDiamondCut(address(diamond)).diamondCut(cuts, address(diamondInit), calldata_);

        return Deployment({
            diamond: diamond,
            diamondCutFacet: diamondCutFacet,
            diamondLoupeFacet: diamondLoupeFacet,
            accessControlFacet: accessControlFacet,
            diamondInit: diamondInit
        });
    }

    function generateDiamondLoupeSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = IDiamondLoupe.facets.selector;
        selectors[1] = IDiamondLoupe.facetFunctionSelectors.selector;
        selectors[2] = IDiamondLoupe.facetAddresses.selector;
        selectors[3] = IDiamondLoupe.facetAddress.selector;
        selectors[4] = IERC165.supportsInterface.selector;
        return selectors;
    }

    function generateAccessControlSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](25);
        selectors[0] = IERC173.owner.selector;
        selectors[1] = IERC173.transferOwnership.selector;
        selectors[2] = AccessControlFacet.getRoleAdmin.selector;
        selectors[3] = AccessControlFacet.getMembers.selector;
        selectors[4] = AccessControlFacet.getTimelockConfig.selector;
        selectors[5] = AccessControlFacet.getPendingAcceptance.selector;
        selectors[6] = AccessControlFacet.admin.selector;
        selectors[7] = AccessControlFacet.getManagers.selector;
        selectors[8] = AccessControlFacet.getKeepers.selector;
        selectors[9] = AccessControlFacet.initialize.selector;
        selectors[10] = AccessControlFacet.setRoleAdmin.selector;
        selectors[11] = AccessControlFacet.setTimelockConfig.selector;
        selectors[12] = AccessControlFacet.grantRole.selector;
        selectors[13] = AccessControlFacet.revokeRole.selector;
        selectors[14] = AccessControlFacet.renounceRole.selector;
        selectors[15] = AccessControlFacet.acceptRole.selector;
        selectors[16] = AccessControlFacet.cancelRoleGrant.selector;
        selectors[17] = AccessControlFacet.checkRoleAcceptance.selector;
        selectors[18] = PermissionedFacet.hasRole.selector;
        selectors[19] = bytes4(keccak256("checkRole(bytes32)"));
        selectors[20] = bytes4(keccak256("checkRole(bytes32,address)"));
        selectors[21] = PermissionedFacet.isAdmin.selector;
        selectors[22] = PermissionedFacet.isManager.selector;
        selectors[23] = PermissionedFacet.isKeeper.selector;
        selectors[24] = PermissionedFacet.isTreasury.selector;
        return selectors;
    }
} 