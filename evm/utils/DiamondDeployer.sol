// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {BTRDiamond} from "../BTRDiamond.sol";
import {DiamondCutFacet} from "../facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../facets/DiamondLoupeFacet.sol";
import {AccessControlFacet} from "../facets/AccessControlFacet.sol";
import {ManagementFacet} from "../facets/ManagementFacet.sol";
import {RescueFacet} from "../facets/RescueFacet.sol";
import {SwapperFacet} from "../facets/SwapperFacet.sol";
import {IDiamondCut} from "../interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../interfaces/IDiamondLoupe.sol";
import {IERC173} from "../interfaces/IERC173.sol";
import {IERC165} from "@openzeppelin/interfaces/IERC165.sol";
import {PermissionedFacet} from "../facets/abstract/PermissionedFacet.sol";
import {ICreateX} from "../interfaces/ICreateX.sol";

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
        ManagementFacet managementFacet;
        RescueFacet rescueFacet;
        SwapperFacet swapperFacet;
        DiamondInit diamondInit;
    }

    struct DeploymentAddresses {
        address diamond;
        address diamondCutFacet;
        address diamondLoupeFacet;
        address accessControlFacet;
        address managementFacet;
        address rescueFacet;
        address swapperFacet;
        address diamondInit;
    }

    struct Salts {
        bytes32 diamond;
        bytes32 diamondCut;
        bytes32 diamondLoupe;
        bytes32 accessControl;
        bytes32 management;
        bytes32 rescue;
        bytes32 swapper;
        bytes32 init;
    }

    /// @notice Deploy diamond and facets using regular CREATE
    function deployDiamond(address admin) external returns (Deployment memory) {
        // Deploy facets
        DiamondCutFacet diamondCutFacet = new DiamondCutFacet();
        DiamondLoupeFacet diamondLoupeFacet = new DiamondLoupeFacet();
        AccessControlFacet accessControlFacet = new AccessControlFacet();
        ManagementFacet managementFacet = new ManagementFacet();
        RescueFacet rescueFacet = new RescueFacet();
        SwapperFacet swapperFacet = new SwapperFacet();
        DiamondInit diamondInit = new DiamondInit();

        // Deploy diamond
        BTRDiamond diamond = new BTRDiamond(admin, address(diamondCutFacet));

        // Initialize diamond
        _initializeDiamond(
            address(diamond),
            admin,
            address(diamondLoupeFacet),
            address(accessControlFacet),
            address(managementFacet),
            address(rescueFacet),
            address(swapperFacet),
            address(diamondInit)
        );

        return Deployment({
            diamond: diamond,
            diamondCutFacet: diamondCutFacet,
            diamondLoupeFacet: diamondLoupeFacet,
            accessControlFacet: accessControlFacet,
            managementFacet: managementFacet,
            rescueFacet: rescueFacet,
            swapperFacet: swapperFacet,
            diamondInit: diamondInit
        });
    }

    /// @notice Deploy diamond and facets deterministically using CREATE3
    /// @param admin Admin address for the diamond
    /// @param salts Pre-compiled salts for each contract, or use default salts if bytes32(0)
    /// @param saltPrefix Prefix for generating default salts
    /// @param createX CreateX contract instance
    function deployDeterministic(
        address admin,
        Salts memory salts,
        string memory saltPrefix,
        ICreateX createX
    ) external returns (DeploymentAddresses memory) {
        // Generate or use provided salts
        Salts memory usedSalts = _resolveSalts(salts, saltPrefix);

        // Deploy facets deterministically
        address diamondCutFacet = createX.deployCreate3(usedSalts.diamondCut, type(DiamondCutFacet).creationCode);
        address diamondLoupeFacet = createX.deployCreate3(usedSalts.diamondLoupe, type(DiamondLoupeFacet).creationCode);
        address accessControlFacet = createX.deployCreate3(usedSalts.accessControl, type(AccessControlFacet).creationCode);
        address managementFacet = createX.deployCreate3(usedSalts.management, type(ManagementFacet).creationCode);
        address rescueFacet = createX.deployCreate3(usedSalts.rescue, type(RescueFacet).creationCode);
        address swapperFacet = createX.deployCreate3(usedSalts.swapper, type(SwapperFacet).creationCode);
        address diamondInit = createX.deployCreate3(usedSalts.init, type(DiamondInit).creationCode);

        // Deploy diamond with constructor args
        bytes memory diamondCreationCode = abi.encodePacked(
            type(BTRDiamond).creationCode,
            abi.encode(admin, diamondCutFacet)
        );
        address diamond = createX.deployCreate3(usedSalts.diamond, diamondCreationCode);

        // Initialize diamond
        _initializeDiamond(
            diamond,
            admin,
            diamondLoupeFacet,
            accessControlFacet,
            managementFacet,
            rescueFacet,
            swapperFacet,
            diamondInit
        );

        return DeploymentAddresses({
            diamond: diamond,
            diamondCutFacet: diamondCutFacet,
            diamondLoupeFacet: diamondLoupeFacet,
            accessControlFacet: accessControlFacet,
            managementFacet: managementFacet,
            rescueFacet: rescueFacet,
            swapperFacet: swapperFacet,
            diamondInit: diamondInit
        });
    }

    /// @notice Simplified version that accepts a single diamond salt
    function deployDeterministic(
        address admin,
        bytes32 diamondSalt,
        string memory saltPrefix,
        ICreateX createX
    ) external returns (DeploymentAddresses memory) {
        Salts memory salts;
        salts.diamond = diamondSalt;
        return this.deployDeterministic(admin, salts, saltPrefix, createX);
    }

    /// @notice Predict addresses for deterministic deployment
    /// @param salts Pre-compiled salts for each contract, or use default salts if bytes32(0)
    /// @param saltPrefix Prefix for generating default salts
    /// @param deployer Address that will deploy the contracts
    /// @param createX CreateX contract instance
    function predictDeterministicAddresses(
        Salts memory salts,
        string memory saltPrefix,
        address deployer,
        ICreateX createX
    ) external view returns (DeploymentAddresses memory) {
        // Generate or use provided salts
        Salts memory usedSalts = _resolveSalts(salts, saltPrefix);

        return DeploymentAddresses({
            diamond: createX.computeCreate3Address(usedSalts.diamond, deployer),
            diamondCutFacet: createX.computeCreate3Address(usedSalts.diamondCut, deployer),
            diamondLoupeFacet: createX.computeCreate3Address(usedSalts.diamondLoupe, deployer),
            accessControlFacet: createX.computeCreate3Address(usedSalts.accessControl, deployer),
            managementFacet: createX.computeCreate3Address(usedSalts.management, deployer),
            rescueFacet: createX.computeCreate3Address(usedSalts.rescue, deployer),
            swapperFacet: createX.computeCreate3Address(usedSalts.swapper, deployer),
            diamondInit: createX.computeCreate3Address(usedSalts.init, deployer)
        });
    }

    /// @notice Simplified version that accepts a single diamond salt
    function predictDeterministicAddresses(
        string memory saltPrefix,
        bytes32 diamondSalt,
        address deployer,
        ICreateX createX
    ) external view returns (DeploymentAddresses memory) {
        Salts memory salts;
        salts.diamond = diamondSalt;
        return this.predictDeterministicAddresses(salts, saltPrefix, deployer, createX);
    }

    /// @notice Resolve salts, using provided salts or generating defaults
    function _resolveSalts(
        Salts memory salts,
        string memory saltPrefix
    ) internal pure returns (Salts memory) {
        Salts memory result = salts;
        
        // Component names for salt generation
        string[8] memory components = [
            ".diamond",
            ".diamondCut",
            ".diamondLoupe",
            ".accessControl",
            ".management",
            ".rescue",
            ".swapper",
            ".init"
        ];
        
        // Get salt references for updating
        bytes32[8] memory saltRefs = [
            result.diamond,
            result.diamondCut,
            result.diamondLoupe,
            result.accessControl,
            result.management,
            result.rescue,
            result.swapper,
            result.init
        ];
        
        // Generate salts for any that are zero
        for (uint i = 0; i < components.length; i++) {
            if (saltRefs[i] == bytes32(0)) {
                saltRefs[i] = keccak256(abi.encodePacked(saltPrefix, components[i]));
            }
        }
        
        // Update result with generated salts
        result.diamond = saltRefs[0];
        result.diamondCut = saltRefs[1];
        result.diamondLoupe = saltRefs[2];
        result.accessControl = saltRefs[3];
        result.management = saltRefs[4];
        result.rescue = saltRefs[5];
        result.swapper = saltRefs[6];
        result.init = saltRefs[7];

        return result;
    }

    /// @notice Initialize diamond with facets
    function _initializeDiamond(
        address diamond,
        address admin,
        address diamondLoupeFacet,
        address accessControlFacet,
        address managementFacet,
        address rescueFacet,
        address swapperFacet,
        address diamondInit
    ) internal {
        // Prepare facet cuts
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](5);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: diamondLoupeFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: generateDiamondLoupeSelectors()
        });
        cuts[1] = IDiamondCut.FacetCut({
            facetAddress: accessControlFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: generateAccessControlSelectors()
        });
        cuts[2] = IDiamondCut.FacetCut({
            facetAddress: managementFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: generateManagementSelectors()
        });
        cuts[3] = IDiamondCut.FacetCut({
            facetAddress: rescueFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: generateRescueSelectors()
        });
        cuts[4] = IDiamondCut.FacetCut({
            facetAddress: swapperFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: generateSwapperSelectors()
        });

        // Execute diamond cut and initialize
        bytes memory calldata_ = abi.encodeWithSelector(DiamondInit.init.selector, admin);
        IDiamondCut(diamond).diamondCut(cuts, diamondInit, calldata_);
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

    function generateManagementSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](23);
        
        bytes4[23] memory selectorValues = [
            ManagementFacet.isPaused.selector,
            ManagementFacet.pause.selector,
            ManagementFacet.unpause.selector,
            ManagementFacet.setfeeBps.selector,
            ManagementFacet.setRestrictedMint.selector,
            ManagementFacet.setMaxSupply.selector,
            ManagementFacet.setAddressType.selector,
            ManagementFacet.setBlacklist.selector,
            ManagementFacet.setTreasury.selector,
            ManagementFacet.isBlacklisted.selector,
            ManagementFacet.getAddressType.selector,
            ManagementFacet.getAddressTypeEnum.selector,
            ManagementFacet.getMaxSupply.selector,
            ManagementFacet.isRestrictedMint.selector,
            ManagementFacet.isRestrictedMinter.selector,
            ManagementFacet.isVaultWhitelisted.selector,
            ManagementFacet.addToVaultWhitelist.selector,
            ManagementFacet.removeFromVaultWhitelist.selector,
            ManagementFacet.setRestrictedMint.selector,
            ManagementFacet.setVaultFee.selector,
            ManagementFacet.getVaultCount.selector,
            ManagementFacet.pauseVault.selector,
            ManagementFacet.unpauseVault.selector
        ];
        
        for (uint i = 0; i < selectorValues.length; i++) {
            selectors[i] = selectorValues[i];
        }
        
        return selectors;
    }

    function generateRescueSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](10);
        
        bytes4[10] memory selectorValues = [
            RescueFacet.getRescueRequest.selector,
            RescueFacet.isRescueLocked.selector,
            RescueFacet.isRescueExpired.selector,
            RescueFacet.isRescueUnlocked.selector,
            RescueFacet.getRescueConfig.selector,
            RescueFacet.setRescueConfig.selector,
            RescueFacet.requestRescue.selector,
            RescueFacet.executeRescue.selector,
            RescueFacet.cancelRescue.selector,
            RescueFacet.initialize.selector
        ];
        
        for (uint i = 0; i < selectorValues.length; i++) {
            selectors[i] = selectorValues[i];
        }
        
        return selectors;
    }

    function generateSwapperSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](5);
        
        bytes4[5] memory selectorValues = [
            SwapperFacet.swap.selector,
            SwapperFacet.decodeAndSwap.selector,
            SwapperFacet.decodeAndSwapBalance.selector,
            SwapperFacet.multiSwap.selector,
            SwapperFacet.multiSwapBalances.selector
        ];
        
        for (uint i = 0; i < selectorValues.length; i++) {
            selectors[i] = selectorValues[i];
        }
        
        return selectors;
    }
}
