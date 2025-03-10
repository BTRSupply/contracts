// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {IDiamondCut} from "interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "interfaces/IDiamondLoupe.sol";
import {BTRDiamond} from "../BTRDiamond.sol";
import {DiamondCutFacet} from "facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "facets/DiamondLoupeFacet.sol";
import {AccessControlFacet} from "facets/AccessControlFacet.sol";
import {LibAccessControl} from "libraries/LibAccessControl.sol";
import {IERC173} from "interfaces/IERC173.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";

/**
 * @title DeployDiamond
 * @notice Forge script to deploy BTR Diamond architecture
 * @dev This script replaces the functionality of BTRVaultInit.sol
 */
contract DeployDiamond is Script {
    // Facet contracts
    DiamondCutFacet diamondCutFacet;
    DiamondLoupeFacet diamondLoupeFacet;
    AccessControlFacet accessControlFacet;
    
    // The Diamond contract
    BTRDiamond diamond;
    
    function run() external {
        // Get deployer private key and address
        uint256 deployerPk = vm.envUint("DEPLOYER_PK");
        address deployer = vm.addr(deployerPk);
        address admin = deployer;
        
        console2.log("Deploying BTR Diamond with admin:", admin);
        
        vm.startBroadcast(deployerPk);

        // 1. Deploy all facets
        deployFacets();

        // 2. Deploy the diamond with the DiamondCutFacet address
        diamond = new BTRDiamond(admin, address(diamondCutFacet));
        
        // 3. Add remaining facets to the diamond
        addFacets();
        
        // 4. Initialize facets
        initializeFacets(admin);
        
        vm.stopBroadcast();
        
        // Print deployment summary
        console2.log("=========== Deployment Summary ===========");
        console2.log("Diamond address:          ", address(diamond));
        console2.log("DiamondCutFacet address:  ", address(diamondCutFacet));
        console2.log("DiamondLoupeFacet address:", address(diamondLoupeFacet));
        console2.log("AccessControlFacet address:", address(accessControlFacet));
        console2.log("Admin address:            ", admin);
        console2.log("=========================================");
    }
    
    /**
     * @notice Deploy all facet contracts
     */
    function deployFacets() internal {
        diamondCutFacet = new DiamondCutFacet();
        diamondLoupeFacet = new DiamondLoupeFacet();
        accessControlFacet = new AccessControlFacet();
        console2.log("Facets deployed successfully");
    }

    /**
     * @notice Add facets to the diamond using diamondCut
     */
    function addFacets() internal {
        // Prepare facet cuts for diamond cut
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](2);
        
        // Diamond Loupe facet
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(diamondLoupeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: generateDiamondLoupeSelectors()
        });
        
        // Access Control facet
        cuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(accessControlFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: generateAccessControlSelectors()
        });
        
        // Execute the diamond cut through the diamond contract
        IDiamondCut(address(diamond)).diamondCut(cuts, address(0), "");
        
        console2.log("Facets added to diamond successfully");
    }
    
    /**
     * @notice Initialize facets with required configuration
     * @param admin The address of the admin
     */
    function initializeFacets(address admin) internal {
        // Initialize AccessControl facet
        (bool success,) = address(diamond).call(
            abi.encodeWithSelector(AccessControlFacet.initialize.selector, admin)
        );
        require(success, "AccessControl initialization failed");

        console2.log("Facets initialized successfully");
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
        // Create an array with all AccessControlFacet function selectors
        bytes4[] memory selectors = new bytes4[](19);
        
        // ERC173 compatibility functions
        selectors[0] = IERC173.owner.selector;
        selectors[1] = IERC173.transferOwnership.selector;
        
        // Role management functions
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
        
        // There is a second initialize function in AccessControlFacet (this might be a duplicate)
        selectors[17] = bytes4(keccak256("initialize(address)"));
        
        // Additional function for role-based check
        selectors[18] = AccessControlFacet.checkRoleAcceptance.selector;
        
        return selectors;
    }
} 