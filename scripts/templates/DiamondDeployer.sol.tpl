// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// Core imports
import {BTRDiamond} from "@/BTRDiamond.sol";
import {IDiamondCut, IDiamondLoupe, IDiamondInit, IDiamondCutCallback} from "@interfaces/IDiamond.sol";
import {IERC173} from "@interfaces/ercs/IERC173.sol";
import {IERC165} from "@interfaces/ercs/IERC165.sol";
import {ICreateX} from "@interfaces/ICreateX.sol";

// Facet imports
// FACET_IMPORTS_PLACEHOLDER

// Diamond initializer contract to avoid stack too deep errors
contract DiamondInit {
    // This function is executed via delegatecall by the diamond when provided as an initialization address
    function init(address admin, address treasury) external {
        // Each of these calls will delegate through the diamond to the respective facet
        
        // We skip AccessControl initialization because it's already done in the BTRDiamond constructor
        // That's why our previous initialization was failing
        // Note: Admin should already have all required roles (ADMIN_ROLE, MANAGER_ROLE, etc.)
        
        bool success;
        
        // Initialize ManagementFacet
        bytes4 initManagement = bytes4(keccak256("initializeManagement()"));
        (success,) = address(this).delegatecall(
            abi.encodeWithSelector(initManagement)
        );
        require(success, "Management initialization failed");
        
        // Initialize RescueFacet
        bytes4 initRescue = bytes4(keccak256("initializeRescue()"));
        (success,) = address(this).delegatecall(
            abi.encodeWithSelector(initRescue)
        );
        require(success, "Rescue initialization failed");
        
        // Initialize SwapperFacet
        bytes4 initSwapper = bytes4(keccak256("initializeSwapper()"));
        (success,) = address(this).delegatecall(
            abi.encodeWithSelector(initSwapper)
        );
        require(success, "Swapper initialization failed");
        
        // Initialize ALMFacet
        bytes4 initALM = bytes4(keccak256("initializeALM()"));
        (success,) = address(this).delegatecall(
            abi.encodeWithSelector(initALM)
        );
        require(success, "ALM initialization failed");
        
        // Initialize TreasuryFacet
        bytes4 initTreasury = bytes4(keccak256("initializeTreasury()"));
        (success,) = address(this).delegatecall(
            abi.encodeWithSelector(initTreasury)
        );
        require(success, "Treasury initialization failed");
        
    }
}

contract DiamondDeployer {
    /// @notice Deployment result containing all deployed contracts
    struct Deployment {
        address diamond;
        address[] facets;
        string[] facetNames;
    }

    /// @notice Deployment addresses for deterministic deployment
    struct DeploymentAddresses {
        address diamond;
        address diamondCutFacet;
        address[] facets;
    }

    /// @notice Salts for deterministic deployment
    struct Salts {
        bytes32 diamond;
        bytes32 diamondCut;
        bytes32[] facets;
    }

    // SELECTOR_FUNCTIONS_PLACEHOLDER

    /// @notice Deploy diamond and facets using regular CREATE
    function deployDiamond(address admin, address treasury) external returns (Deployment memory) {
        require(admin != address(0), "Admin cannot be zero address");
        require(treasury != address(0), "Treasury cannot be zero address");
        
        // Deploy all facets using helper functions to reduce local variables
        (address[] memory facets, string[] memory facetNames) = _deployFacets();
        
        // Deploy initializer contract
        DiamondInit diamondInit = new DiamondInit();
        
        // Deploy diamond with only the DiamondCutFacet
        BTRDiamond diamond = new BTRDiamond(admin, treasury, facets[0]);
        
        // Add the remaining facets via the admin callback
        _addFacetsToDiamond(admin, address(diamond), facets, address(diamondInit), treasury);
        
        return Deployment({
            diamond: address(diamond),
            facets: facets,
            facetNames: facetNames
        });
    }

    /// @notice Helper function to deploy all facets
    function _deployFacets() internal returns (address[] memory facets, string[] memory facetNames) {
        facets = new address[](8);
        facetNames = new string[](8);
        
        // Deploy first batch (0-3)
        (facets[0], facetNames[0]) = _deployFacet1();
        (facets[1], facetNames[1]) = _deployFacet2();
        (facets[2], facetNames[2]) = _deployFacet3();
        (facets[3], facetNames[3]) = _deployFacet4();
        
        // Deploy second batch (4-7)
        (facets[4], facetNames[4]) = _deployFacet5();
        (facets[5], facetNames[5]) = _deployFacet6();
        (facets[6], facetNames[6]) = _deployFacet7();
        (facets[7], facetNames[7]) = _deployFacet8();
        
        return (facets, facetNames);
    }

    /// @notice Helper to deploy DiamondCutFacet
    function _deployFacet1() internal returns (address, string memory) {
        DiamondCutFacet facet = new DiamondCutFacet();
        return (address(facet), "DiamondCutFacet");
    }

    /// @notice Helper to deploy DiamondLoupeFacet
    function _deployFacet2() internal returns (address, string memory) {
        DiamondLoupeFacet facet = new DiamondLoupeFacet();
        return (address(facet), "DiamondLoupeFacet");
    }

    /// @notice Helper to deploy AccessControlFacet
    function _deployFacet3() internal returns (address, string memory) {
        AccessControlFacet facet = new AccessControlFacet();
        return (address(facet), "AccessControlFacet");
    }

    /// @notice Helper to deploy ManagementFacet
    function _deployFacet4() internal returns (address, string memory) {
        ManagementFacet facet = new ManagementFacet();
        return (address(facet), "ManagementFacet");
    }

    /// @notice Helper to deploy RescueFacet
    function _deployFacet5() internal returns (address, string memory) {
        RescueFacet facet = new RescueFacet();
        return (address(facet), "RescueFacet");
    }

    /// @notice Helper to deploy SwapperFacet
    function _deployFacet6() internal returns (address, string memory) {
        SwapperFacet facet = new SwapperFacet();
        return (address(facet), "SwapperFacet");
    }

    /// @notice Helper to deploy ALMFacet
    function _deployFacet7() internal returns (address, string memory) {
        ALMFacet facet = new ALMFacet();
        return (address(facet), "ALMFacet");
    }

    /// @notice Helper to deploy TreasuryFacet
    function _deployFacet8() internal returns (address, string memory) {
        TreasuryFacet facet = new TreasuryFacet();
        return (address(facet), "TreasuryFacet");
    }

    /// @notice Helper to add facets to diamond via admin callback
    function _addFacetsToDiamond(
        address admin, 
        address diamond, 
        address[] memory facets,
        address diamondInit,
        address treasury
    ) internal {
        // Prepare facet cuts - all except the first one which is already in the diamond
        IDiamondCut.FacetCut[] memory cuts = _prepareFacetCuts(facets);
        
        // Prepare initialization calldata
        bytes memory initCalldata = abi.encodeWithSelector(
            DiamondInit.init.selector,
            admin,
            treasury
        );
        
        // Have admin execute the diamondCut
        IDiamondCutCallback(admin).diamondCutCallback(
            diamond,
            cuts,
            diamondInit,
            initCalldata
        );
    }

    /// @notice Helper to prepare facet cuts array
    function _prepareFacetCuts(address[] memory facets) internal pure returns (IDiamondCut.FacetCut[] memory) {
        // Create cuts for all facets except the first one (DiamondCutFacet), which is already in the diamond
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](7);
        
        // Prepare each cut separately to avoid stack too deep issues
        cuts[0] = _prepareFacetCut1(facets[1]);
        cuts[1] = _prepareFacetCut2(facets[2]);
        cuts[2] = _prepareFacetCut3(facets[3]);
        cuts[3] = _prepareFacetCut4(facets[4]);
        cuts[4] = _prepareFacetCut5(facets[5]);
        cuts[5] = _prepareFacetCut6(facets[6]);
        cuts[6] = _prepareFacetCut7(facets[7]);
        
        return cuts;
    }

    /// @notice Helper for DiamondLoupeFacet cut
    function _prepareFacetCut1(address facet) internal pure returns (IDiamondCut.FacetCut memory) {
        return IDiamondCut.FacetCut({
            facetAddress: facet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getDiamondLoupeFacetSelectors()
        });
    }

    /// @notice Helper for AccessControlFacet cut
    function _prepareFacetCut2(address facet) internal pure returns (IDiamondCut.FacetCut memory) {
        return IDiamondCut.FacetCut({
            facetAddress: facet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getAccessControlFacetSelectors()
        });
    }

    /// @notice Helper for ManagementFacet cut
    function _prepareFacetCut3(address facet) internal pure returns (IDiamondCut.FacetCut memory) {
        return IDiamondCut.FacetCut({
            facetAddress: facet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getManagementFacetSelectors()
        });
    }

    /// @notice Helper for RescueFacet cut
    function _prepareFacetCut4(address facet) internal pure returns (IDiamondCut.FacetCut memory) {
        return IDiamondCut.FacetCut({
            facetAddress: facet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getRescueFacetSelectors()
        });
    }

    /// @notice Helper for SwapperFacet cut
    function _prepareFacetCut5(address facet) internal pure returns (IDiamondCut.FacetCut memory) {
        return IDiamondCut.FacetCut({
            facetAddress: facet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getSwapperFacetSelectors()
        });
    }

    /// @notice Helper for ALMFacet cut
    function _prepareFacetCut6(address facet) internal pure returns (IDiamondCut.FacetCut memory) {
        return IDiamondCut.FacetCut({
            facetAddress: facet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getALMFacetSelectors()
        });
    }

    /// @notice Helper for TreasuryFacet cut
    function _prepareFacetCut7(address facet) internal pure returns (IDiamondCut.FacetCut memory) {
        return IDiamondCut.FacetCut({
            facetAddress: facet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getTreasuryFacetSelectors()
        });
    }

    /// @notice Initialize diamond with facets - Deprecated
    function _initializeDiamond(
        address diamond,
        address admin,
        address[] memory facets
    ) internal pure {
        // This function is deprecated in favor of inline initialization in deployDiamond
        revert("Use deployDiamond instead");
    }
    
    /// @notice Helper functions below are not used anymore after refactoring
    function _setupDiamond(address diamond, address admin, address[] memory) internal pure {
        // Deprecated 
        revert("Use deployDiamond instead");
    }
    
    function _addRemainingFacets(address diamond, address[] memory) internal pure {
        // Deprecated
        revert("Use deployDiamond instead");
    }
    
    function _initializeRemainingFacets(address diamond) internal pure {
        // Deprecated
        revert("Use deployDiamond instead");
    }

    /// @notice Helper function to create a FacetCut struct
    function _createFacetCut(
        address facetAddress,
        IDiamondCut.FacetCutAction action,
        bytes4[] memory selectors
    ) internal pure returns (IDiamondCut.FacetCut memory) {
        return IDiamondCut.FacetCut({
            facetAddress: facetAddress,
            action: action,
            functionSelectors: selectors
        });
    }
    
    /// @notice Predict deterministic addresses
    function predictDeterministicAddresses(
        Salts memory /* salts */,
        string memory /* prefix */,
        address /* deployer */,
        ICreateX /* createX */
    ) external pure returns (DeploymentAddresses memory) {
        // This function would normally implement logic to predict addresses
        // Placeholder implementation
        return DeploymentAddresses({
            diamond: address(0),
            diamondCutFacet: address(0),
            facets: new address[](0)
        });
    }
    
    /// @notice Deploy deterministically
    function deployDeterministic(
        address /* admin */,
        Salts memory /* salts */,
        string memory /* prefix */,
        ICreateX /* createX */
    ) external pure returns (DeploymentAddresses memory) {
        // This function would normally implement logic for deterministic deployment
        // Placeholder implementation
        return DeploymentAddresses({
            diamond: address(0),
            diamondCutFacet: address(0),
            facets: new address[](0)
        });
    }
} 