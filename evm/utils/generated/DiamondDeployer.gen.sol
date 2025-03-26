// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// Core imports
import {BTRDiamond} from "@/BTRDiamond.sol";
import {IDiamondCut, IDiamondLoupe, IDiamondInit, IDiamondCutCallback} from "@interfaces/IDiamond.sol";
import {IERC173} from "@interfaces/ercs/IERC173.sol";
import {IERC165} from "@interfaces/ercs/IERC165.sol";
import {ICreateX} from "@interfaces/ICreateX.sol";
import {LibAccessControl} from "@libraries/LibAccessControl.sol";

// Facet imports
import {ManagementFacet} from "@facets/ManagementFacet.sol";
import {DiamondLoupeFacet} from "@facets/DiamondLoupeFacet.sol";
import {RescueFacet} from "@facets/RescueFacet.sol";
import {ALMFacet} from "@facets/ALMFacet.sol";
import {SwapperFacet} from "@facets/SwapperFacet.sol";
import {AccessControlFacet} from "@facets/AccessControlFacet.sol";
import {TreasuryFacet} from "@facets/TreasuryFacet.sol";
import {DiamondCutFacet} from "@facets/DiamondCutFacet.sol";

// Diamond initializer contract to avoid stack too deep errors
contract DiamondInit {
    function init(address admin) external {
        // Since we'll be using delegatecall from the admin account via the diamond, 
        // we need to grant all necessary roles to the admin first to ensure they have permissions
        
        // Direct access to storage to grant roles 
        // These functions directly interact with storage so they don't use onlyAdmin checks
        LibAccessControl.grantRole(LibAccessControl.ADMIN_ROLE, admin);
        LibAccessControl.grantRole(LibAccessControl.MANAGER_ROLE, admin);
        LibAccessControl.grantRole(LibAccessControl.TREASURY_ROLE, admin);
        
        // Now that the admin has all roles, we can initialize all the facets
        bytes4 initManagementSelector = ManagementFacet.initializeManagement.selector;
        bytes4 initRescueSelector = RescueFacet.initializeRescue.selector;
        bytes4 initALMSelector = ALMFacet.initializeALM.selector;
        bytes4 initSwapperSelector = SwapperFacet.initializeSwapper.selector;
        bytes4 initAccessControlSelector = AccessControlFacet.initializeAccessControl.selector;
        bytes4 initTreasurySelector = TreasuryFacet.initializeTreasury.selector;
        (bool success1,) = address(this).call(abi.encodePacked(initManagementSelector));
        if (!success1) {} // ignore error
        (bool success2,) = address(this).call(abi.encodePacked(initRescueSelector));
        if (!success2) {} // ignore error
        (bool success3,) = address(this).call(abi.encodePacked(initALMSelector));
        if (!success3) {} // ignore error
        (bool success4,) = address(this).call(abi.encodePacked(initSwapperSelector));
        if (!success4) {} // ignore error
        (bool success5,) = address(this).call(abi.encodePacked(initAccessControlSelector));
        if (!success5) {} // ignore error
        (bool success6,) = address(this).call(abi.encodePacked(initTreasurySelector));
        if (!success6) {} // ignore error
    }
}

contract DiamondDeployer is IDiamondCutCallback {
    // Store admin address for diamondCutCallback
    address private _admin;

    /// @notice Deployment result containing all deployed contracts
    struct Deployment {
        address diamond;
        address[] facets;
        string[] facetNames;
    }

    /// @notice Deployment addresses for deterministic deployment
    struct DeploymentAddresses {
        address diamond;
        address management;
        address diamond_loupe;
        address rescue;
        address alm;
        address swapper;
        address access_control;
        address treasury;
        address diamond_cut;
    }

    /// @notice Salts for deterministic deployment
    struct Salts {
        bytes32 diamond;
        bytes32 management;
        bytes32 diamond_loupe;
        bytes32 rescue;
        bytes32 alm;
        bytes32 swapper;
        bytes32 access_control;
        bytes32 treasury;
        bytes32 diamond_cut;
    }

    function getManagementFacetSelectors() public pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](45);
        selectors[0] = 0x44337ea1; // addToBlacklist(address)
        selectors[1] = 0xc7054fbe; // addToListBatch(address[],uint8)
        selectors[2] = 0xe43252d7; // addToWhitelist(address)
        selectors[3] = 0xfd4fa05a; // getAccountStatus(address)
        selectors[4] = 0xaa13cb54; // getMaxSupply(uint32)
        selectors[5] = 0xb135a145; // getRangeCount()
        selectors[6] = 0x74d4e491; // getVaultCount()
        selectors[7] = 0x0d8e6e2c; // getVersion()
        selectors[8] = 0xbc141374; // initializeManagement()
        selectors[9] = 0x5c5218dd; // isApproveMax()
        selectors[10] = 0x026e2ab8; // isAutoRevoke()
        selectors[11] = 0x332c2e18; // isBridgeInputRestricted(address)
        selectors[12] = 0xf00791d0; // isBridgeOutputRestricted(address)
        selectors[13] = 0x36ce5d54; // isBridgeRouterRestricted(address)
        selectors[14] = 0xb187bd26; // isPaused()
        selectors[15] = 0xeef4da34; // isPaused(uint32)
        selectors[16] = 0x81f17587; // isRestrictedMint(uint32)
        selectors[17] = 0x290385f1; // isRestrictedMinter(uint32,address)
        selectors[18] = 0x4be461ef; // isSwapCallerRestricted(address)
        selectors[19] = 0xcb3fbbfc; // isSwapInputRestricted(address)
        selectors[20] = 0xc01109a3; // isSwapOutputRestricted(address)
        selectors[21] = 0xeae21c4c; // isSwapRouterRestricted(address)
        selectors[22] = 0x8456cb59; // pause()
        selectors[23] = 0x4cda9b55; // pause(uint32)
        selectors[24] = 0x257f9abf; // removeFromList(address)
        selectors[25] = 0x8829c167; // removeFromListBatch(address[])
        selectors[26] = 0x0ad2b0a1; // setAccountStatus(address,uint8)
        selectors[27] = 0x7b79211d; // setAccountStatusBatch(address[],uint8)
        selectors[28] = 0x831b2a9a; // setApproveMax(bool)
        selectors[29] = 0xd2ae6e69; // setAutoRevoke(bool)
        selectors[30] = 0x54587d6c; // setBridgeInputRestriction(bool)
        selectors[31] = 0x0d95136e; // setBridgeOutputRestriction(bool)
        selectors[32] = 0x6cb1a756; // setBridgeRouterRestriction(bool)
        selectors[33] = 0x0e7d761d; // setMaxSupply(uint32,uint256)
        selectors[34] = 0x8374f11f; // setRangeWeights(uint32,uint256[])
        selectors[35] = 0xeebdd353; // setRestrictedMint(uint32,bool)
        selectors[36] = 0x596012e5; // setRestriction(uint8,bool)
        selectors[37] = 0xb4bea817; // setSwapCallerRestriction(bool)
        selectors[38] = 0xa0da4e2c; // setSwapInputRestriction(bool)
        selectors[39] = 0xc6f6d2e0; // setSwapOutputRestriction(bool)
        selectors[40] = 0x4174af93; // setSwapRouterRestriction(bool)
        selectors[41] = 0xf78203a7; // setVersion(uint8)
        selectors[42] = 0x3f4ba83a; // unpause()
        selectors[43] = 0x446a9aa2; // unpause(uint32)
        selectors[44] = 0x17a4f4bb; // zeroOutRangeWeights(uint32)
        return selectors;
    }
    function getDiamondLoupeFacetSelectors() public pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](8);
        selectors[0] = 0xcdffacc6; // facetAddress(bytes4)
        selectors[1] = 0x52ef6b2c; // facetAddresses()
        selectors[2] = 0x105db9f0; // facetAddressesPaginated(uint256,uint256)
        selectors[3] = 0xadfca15e; // facetFunctionSelectors(address)
        selectors[4] = 0x92b64171; // facetFunctionSelectorsPaginated(address,uint256,uint256)
        selectors[5] = 0x7a0ed627; // facets()
        selectors[6] = 0xd321f735; // facetsPaginated(uint256,uint256)
        selectors[7] = 0x01ffc9a7; // supportsInterface(bytes4)
        return selectors;
    }
    function getRescueFacetSelectors() public pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](21);
        selectors[0] = 0x819f930f; // cancelRescue(address,uint8)
        selectors[1] = 0x0fa9249a; // cancelRescueAll(address)
        selectors[2] = 0xcbc24ad8; // getRescueConfig()
        selectors[3] = 0xe4646ff4; // getRescueRequest(address,uint8)
        selectors[4] = 0xa01832cf; // getRescueStatus(address,uint8)
        selectors[5] = 0xa0191509; // initializeRescue()
        selectors[6] = 0x1d609f1b; // isRescueExpired(address,uint8)
        selectors[7] = 0xf7b32222; // isRescueLocked(address,uint8)
        selectors[8] = 0xcbbaf7a5; // isRescueUnlocked(address,uint8)
        selectors[9] = 0xbc197c81; // onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)
        selectors[10] = 0xf23a6e61; // onERC1155Received(address,address,uint256,uint256,bytes)
        selectors[11] = 0x150b7a02; // onERC721Received(address,address,uint256,bytes)
        selectors[12] = 0x4230da9f; // requestRescueERC1155(address,uint256)
        selectors[13] = 0x96963d2c; // requestRescueERC1155Batch(address,uint256[])
        selectors[14] = 0x5cf4381e; // requestRescueERC20(address[])
        selectors[15] = 0xe56cc39f; // requestRescueERC721(address,uint256)
        selectors[16] = 0xcf40c9a0; // requestRescueERC721Batch(address,uint256[])
        selectors[17] = 0xe261eb86; // requestRescueNative()
        selectors[18] = 0xd7fcf7c9; // rescue(address,uint8)
        selectors[19] = 0xf4e99960; // rescueAll(address)
        selectors[20] = 0x52e6eb11; // setRescueConfig(uint64,uint64)
        return selectors;
    }
    function getALMFacetSelectors() public pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](30);
        selectors[0] = 0xcc67ecc2; // allowance(uint32,address,address)
        selectors[1] = 0x94c89b2c; // balanceOf(uint32,address)
        selectors[2] = 0x7d1c5b25; // collectFees(uint32)
        selectors[3] = 0xaef6a560; // createVault((string,string,address,address,uint256,uint256,uint256))
        selectors[4] = 0x7217322e; // deposit(uint32,uint256,address)
        selectors[5] = 0xc5896e8f; // deposit(uint32,uint256,uint256,address)
        selectors[6] = 0x24f75314; // getDexAdapter(uint8)
        selectors[7] = 0x62f1096c; // getPoolDexAdapter(bytes32)
        selectors[8] = 0xc19b6015; // getRangeDexAdapter(bytes32)
        selectors[9] = 0xa0d96727; // getRatios0(uint32)
        selectors[10] = 0x19a6081a; // getTotalBalances(uint32)
        selectors[11] = 0xc2082974; // getWeights(uint32)
        selectors[12] = 0x0c66e0ec; // initializeALM()
        selectors[13] = 0x000c14c8; // previewDeposit(uint32,uint256)
        selectors[14] = 0x23c6c8de; // previewDeposit(uint32,uint256,uint256)
        selectors[15] = 0x6301a4ef; // previewDeposit0For1(uint32,uint256)
        selectors[16] = 0xc59f8fd6; // previewDeposit1For0(uint32,uint256)
        selectors[17] = 0x53690fac; // previewWithdraw(uint32,uint256)
        selectors[18] = 0x4bd568cc; // previewWithdraw(uint32,uint256,uint256)
        selectors[19] = 0x4375d60b; // previewWithdraw0For1(uint32,uint256)
        selectors[20] = 0x36774627; // previewWithdraw1For0(uint32,uint256)
        selectors[21] = 0x86ff37e0; // rebalance(uint32,((bytes32,bytes32,uint32,bytes32,uint256,uint128,int24,int24)[],address[],address[],bytes[]))
        selectors[22] = 0x140724d4; // targetRatio0(uint32)
        selectors[23] = 0x72818ea9; // targetRatio1(uint32)
        selectors[24] = 0x7288d381; // totalSupply(uint32)
        selectors[25] = 0xd09ae45b; // transfer(uint32,address,uint256)
        selectors[26] = 0x0f0bc28d; // transferFrom(uint32,address,address,uint256)
        selectors[27] = 0x41ee1ade; // updateDexAdapter(uint8,address)
        selectors[28] = 0xcce185b8; // withdraw(uint32,uint256,address)
        selectors[29] = 0x64effbbb; // withdraw(uint32,uint256,uint256,address)
        return selectors;
    }
    function getSwapperFacetSelectors() public pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](6);
        selectors[0] = 0x98cd4036; // decodeAndSwap(address,address,uint256,bytes)
        selectors[1] = 0x0a6ce5b2; // decodeAndSwapBalance(address,address,bytes)
        selectors[2] = 0xb3c42d61; // initializeSwapper()
        selectors[3] = 0x119943f7; // swap(address,address,bytes)
        selectors[4] = 0xb69cbf9f; // swap(address,address,uint256,uint256,address,bytes)
        selectors[5] = 0xe05ee954; // swapBalance(address,address,uint256,address,bytes)
        return selectors;
    }
    function getAccessControlFacetSelectors() public pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](27);
        selectors[0] = 0x36fc1787; // acceptRole(bytes32)
        selectors[1] = 0xf851a440; // admin()
        selectors[2] = 0x0269df4d; // cancelRoleGrant(address)
        selectors[3] = 0xc5b95190; // checkRole(bytes32)
        selectors[4] = 0x12d9a6ad; // checkRole(bytes32,address)
        selectors[5] = 0x6a1f5b56; // checkRoleAcceptance((bytes32,address,uint64),bytes32)
        selectors[6] = 0xb105e39f; // getKeepers()
        selectors[7] = 0xa8d088bb; // getManagers()
        selectors[8] = 0x7b641fbc; // getMembers(bytes32)
        selectors[9] = 0x0e3944a4; // getPendingAcceptance(address)
        selectors[10] = 0x04fcbf24; // getTimelockConfig()
        selectors[11] = 0x2f2ff15d; // grantRole(bytes32,address)
        selectors[12] = 0x91d14854; // hasRole(bytes32,address)
        selectors[13] = 0xfea0c02e; // initializeAccessControl()
        selectors[14] = 0x24d7806c; // isAdmin(address)
        selectors[15] = 0xfe575a87; // isBlacklisted(address)
        selectors[16] = 0x6ba42aaa; // isKeeper(address)
        selectors[17] = 0xf3ae2415; // isManager(address)
        selectors[18] = 0x516f0a1b; // isTreasury(address)
        selectors[19] = 0x3af32abf; // isWhitelisted(address)
        selectors[20] = 0x8da5cb5b; // owner()
        selectors[21] = 0x8bb9c5bf; // renounceRole(bytes32)
        selectors[22] = 0xd547741f; // revokeRole(bytes32,address)
        selectors[23] = 0x1e4e0091; // setRoleAdmin(bytes32,bytes32)
        selectors[24] = 0x1b3e17db; // setTimelockConfig(uint256,uint256)
        selectors[25] = 0xf2fde38b; // transferOwnership(address)
        selectors[26] = 0x61d027b3; // treasury()
        return selectors;
    }
    function getTreasuryFacetSelectors() public pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](11);
        selectors[0] = 0x4a425387; // getAccruedFees(address)
        selectors[1] = 0xe02642fa; // getAccruedFees(uint32,address)
        selectors[2] = 0xdb8d55f1; // getFees()
        selectors[3] = 0x7ab038fa; // getFees(uint32)
        selectors[4] = 0xe0d89b32; // getPendingFees(uint32,address)
        selectors[5] = 0x3b19e84a; // getTreasury()
        selectors[6] = 0x63c5d245; // initializeTreasury()
        selectors[7] = 0xf4b00a30; // setDefaultFees((uint16,uint16,uint16,uint16,uint16,bytes32[8]))
        selectors[8] = 0x4f93456e; // setFees((uint16,uint16,uint16,uint16,uint16,bytes32[8]))
        selectors[9] = 0x7fc021c4; // setFees(uint32,(uint16,uint16,uint16,uint16,uint16,bytes32[8]))
        selectors[10] = 0xf0f44260; // setTreasury(address)
        return selectors;
    }
    function getDiamondCutFacetSelectors() public pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = 0x1f931c1c; // diamondCut((address,uint8,bytes4[])[],address,bytes)
        return selectors;
    }

    /**
     * @notice Diamond Cut Callback for authorization in diamond cut operations
     * @dev This function is implemented for compatibility with both tests and production
     */
    function diamondCutCallback(
        address _diamond, 
        IDiamondCut.FacetCut[] memory _cuts, 
        address _init, 
        bytes memory _calldata
    ) external override {
        // Direct call to the diamond
        (bool success, bytes memory returnData) = _diamond.call(
            abi.encodeWithSelector(
                IDiamondCut.diamondCut.selector,
                _cuts,
                _init,
                _calldata
            )
        );
        
        // Handle errors properly
        if (!success) {
            assembly {
                revert(add(32, returnData), mload(returnData))
            }
        }
    }

    function deployDiamond(address admin, address treasury) public returns (Deployment memory) {
        // Store admin for diamondCutCallback
        _admin = admin;
        
        // Deploy facets
        ManagementFacet _ManagementFacet = new ManagementFacet();
        DiamondLoupeFacet _DiamondLoupeFacet = new DiamondLoupeFacet();
        RescueFacet _RescueFacet = new RescueFacet();
        ALMFacet _ALMFacet = new ALMFacet();
        SwapperFacet _SwapperFacet = new SwapperFacet();
        AccessControlFacet _AccessControlFacet = new AccessControlFacet();
        TreasuryFacet _TreasuryFacet = new TreasuryFacet();
        DiamondCutFacet _DiamondCutFacet = new DiamondCutFacet();

        // Deploy DiamondInit
        DiamondInit diamondInit = new DiamondInit();

        // Create FacetCut array for diamond constructor
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](7);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(_ManagementFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getManagementFacetSelectors()
        });
        cuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(_DiamondLoupeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getDiamondLoupeFacetSelectors()
        });
        cuts[2] = IDiamondCut.FacetCut({
            facetAddress: address(_RescueFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getRescueFacetSelectors()
        });
        cuts[3] = IDiamondCut.FacetCut({
            facetAddress: address(_ALMFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getALMFacetSelectors()
        });
        cuts[4] = IDiamondCut.FacetCut({
            facetAddress: address(_SwapperFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getSwapperFacetSelectors()
        });
        cuts[5] = IDiamondCut.FacetCut({
            facetAddress: address(_AccessControlFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getAccessControlFacetSelectors()
        });
        cuts[6] = IDiamondCut.FacetCut({
            facetAddress: address(_TreasuryFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: getTreasuryFacetSelectors()
        });

        // Initialize the diamond - only construct, don't make the diamond cut
        BTRDiamond diamond = new BTRDiamond(admin, treasury, address(_DiamondCutFacet));

        // Return deployment info without calling diamondCut
        address[] memory facets = new address[](8);
        facets[0] = address(_ManagementFacet);
        facets[1] = address(_DiamondLoupeFacet);
        facets[2] = address(_RescueFacet);
        facets[3] = address(_ALMFacet);
        facets[4] = address(_SwapperFacet);
        facets[5] = address(_AccessControlFacet);
        facets[6] = address(_TreasuryFacet);
        facets[7] = address(_DiamondCutFacet);
        
        string[] memory facetNames = new string[](8);
        facetNames[0] = "ManagementFacet";
        facetNames[1] = "DiamondLoupeFacet";
        facetNames[2] = "RescueFacet";
        facetNames[3] = "ALMFacet";
        facetNames[4] = "SwapperFacet";
        facetNames[5] = "AccessControlFacet";
        facetNames[6] = "TreasuryFacet";
        facetNames[7] = "DiamondCutFacet";

        return Deployment({
            diamond: address(diamond),
            facets: facets,
            facetNames: facetNames
        });
    }

    function deployDiamondViaCreate2(bytes32 salt) public returns (address) {
        return address(0);
    }

    function predictDiamondAddress(bytes32 salt) public view returns (address) {
        return address(0);
    }

    function deployDeterministic(
        address admin,
        Salts memory salts,
        string memory prefix,
        ICreateX createX
    ) public returns (DeploymentAddresses memory) {
        return DeploymentAddresses({
            diamond: address(0),
            management: address(0),
            diamond_loupe: address(0),
            rescue: address(0),
            alm: address(0),
            swapper: address(0),
            access_control: address(0),
            treasury: address(0),
            diamond_cut: address(0)
        });
    }

    function predictDeterministicAddresses(
        Salts memory salts,
        string memory prefix,
        address deployer,
        ICreateX createX
    ) public view returns (DeploymentAddresses memory) {
        return DeploymentAddresses({
            diamond: address(0),
            management: address(0),
            diamond_loupe: address(0),
            rescue: address(0),
            alm: address(0),
            swapper: address(0),
            access_control: address(0),
            treasury: address(0),
            diamond_cut: address(0)
        });
    }
} 