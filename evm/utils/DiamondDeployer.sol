// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {BTRDiamond} from "@/BTRDiamond.sol";
import {DiamondCutFacet} from "@facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "@facets/DiamondLoupeFacet.sol";
import {AccessControlFacet} from "@facets/AccessControlFacet.sol";
import {ManagementFacet} from "@facets/ManagementFacet.sol";
import {RescueFacet} from "@facets/RescueFacet.sol";
import {SwapperFacet} from "@facets/SwapperFacet.sol";
import {IDiamondCut} from "@interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "@interfaces/IDiamondLoupe.sol";
import {IERC173} from "@interfaces/IERC173.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {PermissionedFacet} from "@facets/abstract/PermissionedFacet.sol";
import {ICreateX} from "@interfaces/ICreateX.sol";
import {PausableFacet} from "@facets/abstract/PausableFacet.sol";

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

    /// @notice Deploy all diamond components deterministically, with automatic salt derivation
    /// @param admin Admin address to initialize the diamond with
    /// @param salts Struct containing salts for deterministic addresses
    /// @param saltPrefix String prefix for generating salts
    /// @param createX CreateX contract instance
    function deployDeterministic(
        address admin,
        Salts memory salts,
        string memory saltPrefix,
        ICreateX createX
    ) external returns (DeploymentAddresses memory) {
        // Generate or use provided salts
        Salts memory usedSalts = _resolveSalts(salts, saltPrefix);

        // Create a struct to hold addresses to reduce stack depth
        DeploymentAddresses memory addresses;

        // Deploy facets deterministically
        addresses.diamondCutFacet = createX.deployCreate3(usedSalts.diamondCut, type(DiamondCutFacet).creationCode);
        addresses.diamondLoupeFacet = createX.deployCreate3(usedSalts.diamondLoupe, type(DiamondLoupeFacet).creationCode);
        addresses.accessControlFacet = createX.deployCreate3(usedSalts.accessControl, type(AccessControlFacet).creationCode);
        addresses.managementFacet = createX.deployCreate3(usedSalts.management, type(ManagementFacet).creationCode);
        addresses.rescueFacet = createX.deployCreate3(usedSalts.rescue, type(RescueFacet).creationCode);
        addresses.swapperFacet = createX.deployCreate3(usedSalts.swapper, type(SwapperFacet).creationCode);
        addresses.diamondInit = createX.deployCreate3(usedSalts.init, type(DiamondInit).creationCode);

        // Deploy diamond with constructor args
        bytes memory diamondCreationCode = abi.encodePacked(
            type(BTRDiamond).creationCode,
            abi.encode(admin, addresses.diamondCutFacet)
        );
        addresses.diamond = createX.deployCreate3(usedSalts.diamond, diamondCreationCode);

        // Initialize diamond by passing the struct instead of individual parameters
        _initializeDiamondWithAddresses(addresses, admin);

        return addresses;
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
        
        // Call the main function directly with the constructed salts
        // Generate or use provided salts
        Salts memory usedSalts = _resolveSalts(salts, saltPrefix);

        // Create a struct to hold addresses to reduce stack depth
        DeploymentAddresses memory addresses;

        // Deploy facets deterministically
        addresses.diamondCutFacet = createX.deployCreate3(usedSalts.diamondCut, type(DiamondCutFacet).creationCode);
        addresses.diamondLoupeFacet = createX.deployCreate3(usedSalts.diamondLoupe, type(DiamondLoupeFacet).creationCode);
        addresses.accessControlFacet = createX.deployCreate3(usedSalts.accessControl, type(AccessControlFacet).creationCode);
        addresses.managementFacet = createX.deployCreate3(usedSalts.management, type(ManagementFacet).creationCode);
        addresses.rescueFacet = createX.deployCreate3(usedSalts.rescue, type(RescueFacet).creationCode);
        addresses.swapperFacet = createX.deployCreate3(usedSalts.swapper, type(SwapperFacet).creationCode);
        addresses.diamondInit = createX.deployCreate3(usedSalts.init, type(DiamondInit).creationCode);

        // Deploy diamond with constructor args
        bytes memory diamondCreationCode = abi.encodePacked(
            type(BTRDiamond).creationCode,
            abi.encode(admin, addresses.diamondCutFacet)
        );
        addresses.diamond = createX.deployCreate3(usedSalts.diamond, diamondCreationCode);

        // Initialize diamond by passing the struct instead of individual parameters
        _initializeDiamondWithAddresses(addresses, admin);

        return addresses;
    }

    /// @notice Helper function to initialize diamond with addresses stored in a struct
    function _initializeDiamondWithAddresses(DeploymentAddresses memory addresses, address admin) internal {
        _initializeDiamond(
            addresses.diamond,
            admin,
            addresses.diamondLoupeFacet,
            addresses.accessControlFacet,
            addresses.managementFacet,
            addresses.rescueFacet,
            addresses.swapperFacet,
            addresses.diamondInit
        );
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
    ) external pure returns (DeploymentAddresses memory) {
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

    /// @notice Predict addresses for deterministic deployment (simplified version)
    /// @param saltPrefix Prefix for generating default salts
    /// @param diamondSalt Salt for deploying the diamond
    /// @param deployer Address that will deploy the contracts
    /// @param createX CreateX contract instance
    function predictDeterministicAddresses(
        string memory saltPrefix,
        bytes32 diamondSalt,
        address deployer,
        ICreateX createX
    ) external pure returns (DeploymentAddresses memory) {
        Salts memory salts;
        salts.diamond = diamondSalt;
        
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
        for (uint i = 0; i < components.length;) {
            if (saltRefs[i] == bytes32(0)) {
                saltRefs[i] = keccak256(abi.encodePacked(saltPrefix, components[i]));
            }
            unchecked { ++i; }
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
        
        // Use helper functions to create FacetCut structs
        cuts[0] = _createFacetCut(diamondLoupeFacet, IDiamondCut.FacetCutAction.Add, generateDiamondLoupeSelectors());
        cuts[1] = _createFacetCut(accessControlFacet, IDiamondCut.FacetCutAction.Add, generateAccessControlSelectors());
        cuts[2] = _createFacetCut(managementFacet, IDiamondCut.FacetCutAction.Add, generateManagementSelectors());
        cuts[3] = _createFacetCut(rescueFacet, IDiamondCut.FacetCutAction.Add, generateRescueSelectors());
        cuts[4] = _createFacetCut(swapperFacet, IDiamondCut.FacetCutAction.Add, generateSwapperSelectors());

        // Execute diamond cut and initialize
        bytes memory calldata_ = abi.encodeWithSelector(DiamondInit.init.selector, admin);
        IDiamondCut(diamond).diamondCut(cuts, diamondInit, calldata_);
    }
    
    /// @notice Helper function to create a FacetCut struct
    /// @param facetAddress The facet address
    /// @param action The FacetCutAction (Add, Replace, Remove)
    /// @param selectors The function selectors
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
        bytes4[] memory selectors = new bytes4[](24);
        selectors[0] = IERC173.owner.selector;
        selectors[1] = IERC173.transferOwnership.selector;
        selectors[2] = AccessControlFacet.getMembers.selector;
        selectors[3] = AccessControlFacet.getTimelockConfig.selector;
        selectors[4] = AccessControlFacet.getPendingAcceptance.selector;
        selectors[5] = AccessControlFacet.admin.selector;
        selectors[6] = AccessControlFacet.getManagers.selector;
        selectors[7] = AccessControlFacet.getKeepers.selector;
        selectors[8] = AccessControlFacet.initialize.selector;
        selectors[9] = AccessControlFacet.setRoleAdmin.selector;
        selectors[10] = AccessControlFacet.setTimelockConfig.selector;
        selectors[11] = AccessControlFacet.grantRole.selector;
        selectors[12] = AccessControlFacet.revokeRole.selector;
        selectors[13] = AccessControlFacet.renounceRole.selector;
        selectors[14] = AccessControlFacet.acceptRole.selector;
        selectors[15] = AccessControlFacet.cancelRoleGrant.selector;
        selectors[16] = AccessControlFacet.checkRoleAcceptance.selector;
        selectors[17] = PermissionedFacet.hasRole.selector;
        selectors[18] = bytes4(keccak256("checkRole(bytes32)"));
        selectors[19] = bytes4(keccak256("checkRole(bytes32,address)"));
        selectors[20] = PermissionedFacet.isAdmin.selector;
        selectors[21] = PermissionedFacet.isManager.selector;
        selectors[22] = PermissionedFacet.isKeeper.selector;
        selectors[23] = PermissionedFacet.isTreasury.selector;
        return selectors;
    }

    function generateManagementSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](26);
        
        bytes4[26] memory selectorValues = [
            bytes4(keccak256("isPaused()")),
            bytes4(keccak256("pause()")),
            bytes4(keccak256("unpause()")),
            bytes4(keccak256("setfeeBps(uint32,uint16)")),
            bytes4(keccak256("setMaxSupply(uint32,uint256)")),
            bytes4(keccak256("setAddressType(address,uint8)")),
            bytes4(keccak256("setBlacklist(address,bool)")),
            bytes4(keccak256("setTreasury(address)")),
            bytes4(keccak256("isBlacklisted(address)")),
            bytes4(keccak256("getAddressType(address)")),
            bytes4(keccak256("getfeeBps(uint32)")),
            bytes4(keccak256("getMaxSupply(uint32)")),
            bytes4(keccak256("getTreasury()")),
            bytes4(keccak256("getVersion()")),
            bytes4(keccak256("setVersion(uint8)")),
            bytes4(keccak256("pause(uint32)")),
            bytes4(keccak256("unpause(uint32)")),
            bytes4(keccak256("isPaused(uint32)")),
            bytes4(keccak256("setWhitelist(address,bool)")),
            bytes4(keccak256("isWhitelisted(address)")),
            bytes4(keccak256("setRestrictedMint(uint32,bool)")),
            bytes4(keccak256("isRestrictedMint(uint32)")),
            bytes4(keccak256("isRestrictedMinter(address,uint32)")),
            bytes4(keccak256("isVaultWhitelisted(address,uint32)")),
            bytes4(keccak256("addToVaultWhitelist(address,uint32)")),
            bytes4(keccak256("removeFromVaultWhitelist(address,uint32)"))
        ];
        
        for (uint i = 0; i < selectorValues.length;) {
            selectors[i] = selectorValues[i];
            unchecked { ++i; }
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
            bytes4(keccak256("requestRescueERC20(address[])")),
            bytes4(keccak256("rescue(address,uint8)")),
            bytes4(keccak256("cancelRescue(address,uint8)")),
            RescueFacet.initialize.selector
        ];
        
        for (uint i = 0; i < selectorValues.length;) {
            selectors[i] = selectorValues[i];
            unchecked { ++i; }
        }
        
        return selectors;
    }

    function generateSwapperSelectors() internal pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](3);
        
        bytes4[3] memory selectorValues = [
            SwapperFacet.swap.selector,
            SwapperFacet.decodeAndSwap.selector,
            SwapperFacet.decodeAndSwapBalance.selector
        ];
        
        for (uint i = 0; i < selectorValues.length;) {
            selectors[i] = selectorValues[i];
            unchecked { ++i; }
        }
        
        return selectors;
    }
}
