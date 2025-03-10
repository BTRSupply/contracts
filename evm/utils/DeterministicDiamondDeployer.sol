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
import {CREATE3} from "./Create3.sol";

/**
 * @title DeterministicDiamondInit
 * @notice Initializer contract for the diamond, deployed deterministically
 */
contract DeterministicDiamondInit {
    /// @notice Initialize the diamond with initial settings
    /// @param _admin Admin address
    function init(address _admin) external {
        // Initialize the access control
        AccessControlFacet(address(this)).initialize(_admin);
    }
}

/**
 * @title DeterministicDiamondDeployer
 * @notice Utility contract to deploy the diamond and its facets to deterministic addresses using CREATE3
 */
contract DeterministicDiamondDeployer {
    struct Deployment {
        BTRDiamond diamond;
        DiamondCutFacet diamondCutFacet;
        DiamondLoupeFacet diamondLoupeFacet;
        AccessControlFacet accessControlFacet;
        DeterministicDiamondInit diamondInit;
        bytes32 diamondSalt;
        bytes32 diamondCutFacetSalt;
        bytes32 diamondLoupeFacetSalt;
        bytes32 accessControlFacetSalt;
        bytes32 diamondInitSalt;
    }

    /**
     * @notice Deploy diamond and facets to deterministic addresses
     * @param admin Admin address for the diamond
     * @param diamondSalt Salt for diamond deployment
     * @param facetSaltPrefix Prefix to be used for generating facet salts
     * @return deployment Struct containing all deployed contracts and their salts
     */
    function deployDeterministic(
        address admin,
        bytes32 diamondSalt,
        string memory facetSaltPrefix
    ) external returns (Deployment memory deployment) {
        // Generate salts for each facet
        bytes32 diamondCutFacetSalt = keccak256(abi.encodePacked(facetSaltPrefix, ".diamondCut"));
        bytes32 diamondLoupeFacetSalt = keccak256(abi.encodePacked(facetSaltPrefix, ".diamondLoupe"));
        bytes32 accessControlFacetSalt = keccak256(abi.encodePacked(facetSaltPrefix, ".accessControl"));
        bytes32 diamondInitSalt = keccak256(abi.encodePacked(facetSaltPrefix, ".diamondInit"));

        // Deploy facets deterministically
        DiamondCutFacet diamondCutFacet = DiamondCutFacet(
            deployContract(type(DiamondCutFacet).creationCode, diamondCutFacetSalt)
        );

        DiamondLoupeFacet diamondLoupeFacet = DiamondLoupeFacet(
            deployContract(type(DiamondLoupeFacet).creationCode, diamondLoupeFacetSalt)
        );

        AccessControlFacet accessControlFacet = AccessControlFacet(
            deployContract(type(AccessControlFacet).creationCode, accessControlFacetSalt)
        );

        DeterministicDiamondInit diamondInit = DeterministicDiamondInit(
            deployContract(type(DeterministicDiamondInit).creationCode, diamondInitSalt)
        );

        // Deploy diamond deterministically
        BTRDiamond diamond = BTRDiamond(
            deployContract(
                abi.encodePacked(type(BTRDiamond).creationCode, abi.encode(admin, address(diamondCutFacet))),
                diamondSalt
            )
        );

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
        bytes memory calldata_ = abi.encodeWithSelector(DeterministicDiamondInit.init.selector, admin);
        IDiamondCut(address(diamond)).diamondCut(cuts, address(diamondInit), calldata_);

        // Return deployment info
        return Deployment({
            diamond: diamond,
            diamondCutFacet: diamondCutFacet,
            diamondLoupeFacet: diamondLoupeFacet,
            accessControlFacet: accessControlFacet,
            diamondInit: diamondInit,
            diamondSalt: diamondSalt,
            diamondCutFacetSalt: diamondCutFacetSalt,
            diamondLoupeFacetSalt: diamondLoupeFacetSalt,
            accessControlFacetSalt: accessControlFacetSalt,
            diamondInitSalt: diamondInitSalt
        });
    }

    /**
     * @notice Predict addresses for a deterministic deployment without actually deploying
     * @param facetSaltPrefix Prefix to be used for generating facet salts
     * @param diamondSalt Salt for diamond deployment
     * @return diamond Predicted diamond address
     * @return diamondCutFacet Predicted diamondCutFacet address
     * @return diamondLoupeFacet Predicted diamondLoupeFacet address
     * @return accessControlFacet Predicted accessControlFacet address
     * @return diamondInit Predicted diamondInit address
     */
    function predictDeterministicAddresses(
        string memory facetSaltPrefix,
        bytes32 diamondSalt
    ) external view returns (
        address diamond,
        address diamondCutFacet,
        address diamondLoupeFacet,
        address accessControlFacet,
        address diamondInit
    ) {
        // Generate salts for each facet
        bytes32 diamondCutFacetSalt = keccak256(abi.encodePacked(facetSaltPrefix, ".diamondCut"));
        bytes32 diamondLoupeFacetSalt = keccak256(abi.encodePacked(facetSaltPrefix, ".diamondLoupe"));
        bytes32 accessControlFacetSalt = keccak256(abi.encodePacked(facetSaltPrefix, ".accessControl"));
        bytes32 diamondInitSalt = keccak256(abi.encodePacked(facetSaltPrefix, ".diamondInit"));

        // Predict addresses
        diamondCutFacet = CREATE3.predictDeterministicAddress(diamondCutFacetSalt);
        diamondLoupeFacet = CREATE3.predictDeterministicAddress(diamondLoupeFacetSalt);
        accessControlFacet = CREATE3.predictDeterministicAddress(accessControlFacetSalt);
        diamondInit = CREATE3.predictDeterministicAddress(diamondInitSalt);
        diamond = CREATE3.predictDeterministicAddress(diamondSalt);

        return (
            diamond,
            diamondCutFacet,
            diamondLoupeFacet,
            accessControlFacet,
            diamondInit
        );
    }

    /**
     * @notice Helper function to deploy a contract using CREATE3
     * @param creationCode Contract creation code
     * @param salt Deployment salt
     * @return deployed Address of the deployed contract
     */
    function deployContract(bytes memory creationCode, bytes32 salt) internal returns (address deployed) {
        deployed = CREATE3.deployDeterministic(creationCode, salt);
    }

    /**
     * @notice Generate function selectors for DiamondLoupeFacet
     * @return selectors Array of function selectors
     */
    function generateDiamondLoupeSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = IDiamondLoupe.facets.selector;
        selectors[1] = IDiamondLoupe.facetFunctionSelectors.selector;
        selectors[2] = IDiamondLoupe.facetAddresses.selector;
        selectors[3] = IDiamondLoupe.facetAddress.selector;
        selectors[4] = IERC165.supportsInterface.selector;
        return selectors;
    }

    /**
     * @notice Generate function selectors for AccessControlFacet
     * @return selectors Array of function selectors
     */
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