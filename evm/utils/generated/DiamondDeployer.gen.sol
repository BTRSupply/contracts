// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// Core imports
import {BTRDiamond} from "@/BTRDiamond.sol";
import {IDiamondCut} from "@interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "@interfaces/IDiamondLoupe.sol";
import {IERC173} from "@interfaces/ercs/IERC173.sol";
import {IERC165} from "@interfaces/ercs/IERC165.sol";
import {ICreateX} from "@interfaces/ICreateX.sol";

// Facet imports
import {DiamondCutFacet} from "@facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "@facets/DiamondLoupeFacet.sol";
import {AccessControlFacet} from "@facets/AccessControlFacet.sol";
import {ManagementFacet} from "@facets/ManagementFacet.sol";
import {RescueFacet} from "@facets/RescueFacet.sol";
import {SwapperFacet} from "@facets/SwapperFacet.sol";
import {ALMFacet} from "@facets/ALMFacet.sol";
import {TreasuryFacet} from "@facets/TreasuryFacet.sol";

// Interface to allow admin to call diamondCut
interface IDiamondInit {
    function init(address admin) external;
}

// Diamond Cut Callback interface
interface IDiamondCutCallback {
    function diamondCutCallback(address diamond, IDiamondCut.FacetCut[] memory cuts, address init, bytes memory _calldata) external;
}

// Diamond initializer contract to avoid stack too deep errors
contract DiamondInit {
    // This function is executed via delegatecall by the diamond when provided as an initialization address
    function init(address admin) external {
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

        // Function selectors for DiamondCutFacet
    function getDiamondCutFacetSelectors() public pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = bytes4(0x1f931c1c); /* diamondCut((address,uint8,bytes4[])[],address,bytes) */
        return selectors;
    }

    // Function selectors for DiamondLoupeFacet
    function getDiamondLoupeFacetSelectors() public pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](8);
        selectors[0] = bytes4(0xcdffacc6); /* facetAddress(bytes4) */
        selectors[1] = bytes4(0x52ef6b2c); /* facetAddresses() */
        selectors[2] = bytes4(0x105db9f0); /* facetAddressesPaginated(uint256,uint256) */
        selectors[3] = bytes4(0xadfca15e); /* facetFunctionSelectors(address) */
        selectors[4] = bytes4(0x92b64171); /* facetFunctionSelectorsPaginated(address,uint256,uint256) */
        selectors[5] = bytes4(0x7a0ed627); /* facets() */
        selectors[6] = bytes4(0xd321f735); /* facetsPaginated(uint256,uint256) */
        selectors[7] = bytes4(0x01ffc9a7); /* supportsInterface(bytes4) */
        return selectors;
    }

    // Function selectors for AccessControlFacet
    function getAccessControlFacetSelectors() public pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](24);
        selectors[0] = bytes4(0x36fc1787); /* acceptRole(bytes32) */
        selectors[1] = bytes4(0xf851a440); /* admin() */
        selectors[2] = bytes4(0x0269df4d); /* cancelRoleGrant(address) */
        selectors[3] = bytes4(0xc5b95190); /* checkRole(bytes32) */
        selectors[4] = bytes4(0x12d9a6ad); /* checkRole(bytes32,address) */
        selectors[5] = bytes4(0x6a1f5b56); /* checkRoleAcceptance((bytes32,address,uint64),bytes32) */
        selectors[6] = bytes4(0xb105e39f); /* getKeepers() */
        selectors[7] = bytes4(0xa8d088bb); /* getManagers() */
        selectors[8] = bytes4(0x7b641fbc); /* getMembers(bytes32) */
        selectors[9] = bytes4(0x0e3944a4); /* getPendingAcceptance(address) */
        selectors[10] = bytes4(0x04fcbf24); /* getTimelockConfig() */
        selectors[11] = bytes4(0x2f2ff15d); /* grantRole(bytes32,address) */
        selectors[12] = bytes4(0x91d14854); /* hasRole(bytes32,address) */
        selectors[13] = bytes4(0x9fff43bb); /* initializeAccessControl(address) */
        selectors[14] = bytes4(0x24d7806c); /* isAdmin(address) */
        selectors[15] = bytes4(0x6ba42aaa); /* isKeeper(address) */
        selectors[16] = bytes4(0xf3ae2415); /* isManager(address) */
        selectors[17] = bytes4(0x516f0a1b); /* isTreasury(address) */
        selectors[18] = bytes4(0x8da5cb5b); /* owner() */
        selectors[19] = bytes4(0x8bb9c5bf); /* renounceRole(bytes32) */
        selectors[20] = bytes4(0xd547741f); /* revokeRole(bytes32,address) */
        selectors[21] = bytes4(0x1e4e0091); /* setRoleAdmin(bytes32,bytes32) */
        selectors[22] = bytes4(0x1b3e17db); /* setTimelockConfig(uint256,uint256) */
        selectors[23] = bytes4(0xf2fde38b); /* transferOwnership(address) */
        return selectors;
    }

    // Function selectors for ManagementFacet
    function getManagementFacetSelectors() public pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](47);
        selectors[0] = bytes4(0x44337ea1); /* addToBlacklist(address) */
        selectors[1] = bytes4(0xc7054fbe); /* addToListBatch(address[],uint8) */
        selectors[2] = bytes4(0xe43252d7); /* addToWhitelist(address) */
        selectors[3] = bytes4(0xfd4fa05a); /* getAccountStatus(address) */
        selectors[4] = bytes4(0xaa13cb54); /* getMaxSupply(uint32) */
        selectors[5] = bytes4(0xb135a145); /* getRangeCount() */
        selectors[6] = bytes4(0x74d4e491); /* getVaultCount() */
        selectors[7] = bytes4(0x0d8e6e2c); /* getVersion() */
        selectors[8] = bytes4(0xbc141374); /* initializeManagement() */
        selectors[9] = bytes4(0x5c5218dd); /* isApproveMax() */
        selectors[10] = bytes4(0x026e2ab8); /* isAutoRevoke() */
        selectors[11] = bytes4(0xfe575a87); /* isBlacklisted(address) */
        selectors[12] = bytes4(0x332c2e18); /* isBridgeInputRestricted(address) */
        selectors[13] = bytes4(0xf00791d0); /* isBridgeOutputRestricted(address) */
        selectors[14] = bytes4(0x36ce5d54); /* isBridgeRouterRestricted(address) */
        selectors[15] = bytes4(0xb187bd26); /* isPaused() */
        selectors[16] = bytes4(0xeef4da34); /* isPaused(uint32) */
        selectors[17] = bytes4(0x81f17587); /* isRestrictedMint(uint32) */
        selectors[18] = bytes4(0x290385f1); /* isRestrictedMinter(uint32,address) */
        selectors[19] = bytes4(0x4be461ef); /* isSwapCallerRestricted(address) */
        selectors[20] = bytes4(0xcb3fbbfc); /* isSwapInputRestricted(address) */
        selectors[21] = bytes4(0xc01109a3); /* isSwapOutputRestricted(address) */
        selectors[22] = bytes4(0xeae21c4c); /* isSwapRouterRestricted(address) */
        selectors[23] = bytes4(0x3af32abf); /* isWhitelisted(address) */
        selectors[24] = bytes4(0x8456cb59); /* pause() */
        selectors[25] = bytes4(0x4cda9b55); /* pause(uint32) */
        selectors[26] = bytes4(0x257f9abf); /* removeFromList(address) */
        selectors[27] = bytes4(0x8829c167); /* removeFromListBatch(address[]) */
        selectors[28] = bytes4(0x0ad2b0a1); /* setAccountStatus(address,uint8) */
        selectors[29] = bytes4(0x7b79211d); /* setAccountStatusBatch(address[],uint8) */
        selectors[30] = bytes4(0x831b2a9a); /* setApproveMax(bool) */
        selectors[31] = bytes4(0xd2ae6e69); /* setAutoRevoke(bool) */
        selectors[32] = bytes4(0x54587d6c); /* setBridgeInputRestriction(bool) */
        selectors[33] = bytes4(0x0d95136e); /* setBridgeOutputRestriction(bool) */
        selectors[34] = bytes4(0x6cb1a756); /* setBridgeRouterRestriction(bool) */
        selectors[35] = bytes4(0x0e7d761d); /* setMaxSupply(uint32,uint256) */
        selectors[36] = bytes4(0x8374f11f); /* setRangeWeights(uint32,uint256[]) */
        selectors[37] = bytes4(0xeebdd353); /* setRestrictedMint(uint32,bool) */
        selectors[38] = bytes4(0x596012e5); /* setRestriction(uint8,bool) */
        selectors[39] = bytes4(0xb4bea817); /* setSwapCallerRestriction(bool) */
        selectors[40] = bytes4(0xa0da4e2c); /* setSwapInputRestriction(bool) */
        selectors[41] = bytes4(0xc6f6d2e0); /* setSwapOutputRestriction(bool) */
        selectors[42] = bytes4(0x4174af93); /* setSwapRouterRestriction(bool) */
        selectors[43] = bytes4(0xf78203a7); /* setVersion(uint8) */
        selectors[44] = bytes4(0x3f4ba83a); /* unpause() */
        selectors[45] = bytes4(0x446a9aa2); /* unpause(uint32) */
        selectors[46] = bytes4(0x17a4f4bb); /* zeroOutRangeWeights(uint32) */
        return selectors;
    }

    // Function selectors for RescueFacet
    function getRescueFacetSelectors() public pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](21);
        selectors[0] = bytes4(0x819f930f); /* cancelRescue(address,uint8) */
        selectors[1] = bytes4(0x0fa9249a); /* cancelRescueAll(address) */
        selectors[2] = bytes4(0xcbc24ad8); /* getRescueConfig() */
        selectors[3] = bytes4(0xe4646ff4); /* getRescueRequest(address,uint8) */
        selectors[4] = bytes4(0xa01832cf); /* getRescueStatus(address,uint8) */
        selectors[5] = bytes4(0xa0191509); /* initializeRescue() */
        selectors[6] = bytes4(0x1d609f1b); /* isRescueExpired(address,uint8) */
        selectors[7] = bytes4(0xf7b32222); /* isRescueLocked(address,uint8) */
        selectors[8] = bytes4(0xcbbaf7a5); /* isRescueUnlocked(address,uint8) */
        selectors[9] = bytes4(0xbc197c81); /* onERC1155BatchReceived(address,address,uint256[],uint256[],bytes) */
        selectors[10] = bytes4(0xf23a6e61); /* onERC1155Received(address,address,uint256,uint256,bytes) */
        selectors[11] = bytes4(0x150b7a02); /* onERC721Received(address,address,uint256,bytes) */
        selectors[12] = bytes4(0x4230da9f); /* requestRescueERC1155(address,uint256) */
        selectors[13] = bytes4(0x96963d2c); /* requestRescueERC1155Batch(address,uint256[]) */
        selectors[14] = bytes4(0x5cf4381e); /* requestRescueERC20(address[]) */
        selectors[15] = bytes4(0xe56cc39f); /* requestRescueERC721(address,uint256) */
        selectors[16] = bytes4(0xcf40c9a0); /* requestRescueERC721Batch(address,uint256[]) */
        selectors[17] = bytes4(0xe261eb86); /* requestRescueNative() */
        selectors[18] = bytes4(0xd7fcf7c9); /* rescue(address,uint8) */
        selectors[19] = bytes4(0xf4e99960); /* rescueAll(address) */
        selectors[20] = bytes4(0x52e6eb11); /* setRescueConfig(uint64,uint64) */
        return selectors;
    }

    // Function selectors for SwapperFacet
    function getSwapperFacetSelectors() public pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](6);
        selectors[0] = bytes4(0x98cd4036); /* decodeAndSwap(address,address,uint256,bytes) */
        selectors[1] = bytes4(0x0a6ce5b2); /* decodeAndSwapBalance(address,address,bytes) */
        selectors[2] = bytes4(0xb3c42d61); /* initializeSwapper() */
        selectors[3] = bytes4(0x119943f7); /* swap(address,address,bytes) */
        selectors[4] = bytes4(0xb69cbf9f); /* swap(address,address,uint256,uint256,address,bytes) */
        selectors[5] = bytes4(0xe05ee954); /* swapBalance(address,address,uint256,address,bytes) */
        return selectors;
    }

    // Function selectors for ALMFacet
    function getALMFacetSelectors() public pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](30);
        selectors[0] = bytes4(0xcc67ecc2); /* allowance(uint32,address,address) */
        selectors[1] = bytes4(0x94c89b2c); /* balanceOf(uint32,address) */
        selectors[2] = bytes4(0x7d1c5b25); /* collectFees(uint32) */
        selectors[3] = bytes4(0xaef6a560); /* createVault((string,string,address,address,uint256,uint256,uint256)) */
        selectors[4] = bytes4(0x7217322e); /* deposit(uint32,uint256,address) */
        selectors[5] = bytes4(0xc5896e8f); /* deposit(uint32,uint256,uint256,address) */
        selectors[6] = bytes4(0x24f75314); /* getDexAdapter(uint8) */
        selectors[7] = bytes4(0x62f1096c); /* getPoolDexAdapter(bytes32) */
        selectors[8] = bytes4(0xc19b6015); /* getRangeDexAdapter(bytes32) */
        selectors[9] = bytes4(0xa0d96727); /* getRatios0(uint32) */
        selectors[10] = bytes4(0x19a6081a); /* getTotalBalances(uint32) */
        selectors[11] = bytes4(0xc2082974); /* getWeights(uint32) */
        selectors[12] = bytes4(0x0c66e0ec); /* initializeALM() */
        selectors[13] = bytes4(0x000c14c8); /* previewDeposit(uint32,uint256) */
        selectors[14] = bytes4(0x23c6c8de); /* previewDeposit(uint32,uint256,uint256) */
        selectors[15] = bytes4(0x6301a4ef); /* previewDeposit0For1(uint32,uint256) */
        selectors[16] = bytes4(0xc59f8fd6); /* previewDeposit1For0(uint32,uint256) */
        selectors[17] = bytes4(0x53690fac); /* previewWithdraw(uint32,uint256) */
        selectors[18] = bytes4(0x4bd568cc); /* previewWithdraw(uint32,uint256,uint256) */
        selectors[19] = bytes4(0x4375d60b); /* previewWithdraw0For1(uint32,uint256) */
        selectors[20] = bytes4(0x36774627); /* previewWithdraw1For0(uint32,uint256) */
        selectors[21] = bytes4(0x86ff37e0); /* rebalance(uint32,((bytes32,bytes32,uint32,bytes32,uint256,uint128,int24,int24)[],address[],address[],bytes[])) */
        selectors[22] = bytes4(0x140724d4); /* targetRatio0(uint32) */
        selectors[23] = bytes4(0x72818ea9); /* targetRatio1(uint32) */
        selectors[24] = bytes4(0x7288d381); /* totalSupply(uint32) */
        selectors[25] = bytes4(0xd09ae45b); /* transfer(uint32,address,uint256) */
        selectors[26] = bytes4(0x0f0bc28d); /* transferFrom(uint32,address,address,uint256) */
        selectors[27] = bytes4(0x41ee1ade); /* updateDexAdapter(uint8,address) */
        selectors[28] = bytes4(0xcce185b8); /* withdraw(uint32,uint256,address) */
        selectors[29] = bytes4(0x64effbbb); /* withdraw(uint32,uint256,uint256,address) */
        return selectors;
    }

    // Function selectors for TreasuryFacet
    function getTreasuryFacetSelectors() public pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](11);
        selectors[0] = bytes4(0x4a425387); /* getAccruedFees(address) */
        selectors[1] = bytes4(0xe02642fa); /* getAccruedFees(uint32,address) */
        selectors[2] = bytes4(0xdb8d55f1); /* getFees() */
        selectors[3] = bytes4(0x7ab038fa); /* getFees(uint32) */
        selectors[4] = bytes4(0xe0d89b32); /* getPendingFees(uint32,address) */
        selectors[5] = bytes4(0x3b19e84a); /* getTreasury() */
        selectors[6] = bytes4(0x63c5d245); /* initializeTreasury() */
        selectors[7] = bytes4(0xf4b00a30); /* setDefaultFees((uint16,uint16,uint16,uint16,uint16,bytes32[8])) */
        selectors[8] = bytes4(0x4f93456e); /* setFees((uint16,uint16,uint16,uint16,uint16,bytes32[8])) */
        selectors[9] = bytes4(0x7fc021c4); /* setFees(uint32,(uint16,uint16,uint16,uint16,uint16,bytes32[8])) */
        selectors[10] = bytes4(0xf0f44260); /* setTreasury(address) */
        return selectors;
    }


    /// @notice Deploy diamond and facets using regular CREATE
    function deployDiamond(address admin) external returns (Deployment memory) {
        require(admin != address(0), "Admin cannot be zero address");
        
        // Deploy all facets using helper functions to reduce local variables
        (address[] memory facets, string[] memory facetNames) = _deployFacets();
        
        // Deploy initializer contract
        DiamondInit diamondInit = new DiamondInit();
        
        // Deploy diamond with only the DiamondCutFacet
        BTRDiamond diamond = new BTRDiamond(admin, facets[0]);
        
        // Add the remaining facets via the admin callback
        _addFacetsToDiamond(admin, address(diamond), facets, address(diamondInit));
        
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
        address diamondInit
    ) internal {
        // Prepare facet cuts - all except the first one which is already in the diamond
        IDiamondCut.FacetCut[] memory cuts = _prepareFacetCuts(facets);
        
        // Prepare initialization calldata
        bytes memory initCalldata = abi.encodeWithSelector(
            DiamondInit.init.selector,
            admin
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