// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {DiamondDeployer, IDiamondCutCallback} from "@utils/generated/DiamondDeployer.gen.sol";
import {AccessControlFacet} from "@facets/AccessControlFacet.sol";
import {LibAccessControl} from "@libraries/LibAccessControl.sol";
import {IDiamondCut} from "@interfaces/IDiamondCut.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * @title BaseTest
 * @notice Base contract for all diamond tests with standard setup and interface implementations
 * @dev This contract handles diamond deployment and provides standard interface implementations
 */
contract BaseTest is Test, IDiamondCutCallback, IERC721Receiver, IERC1155Receiver {
    address payable public diamond;
    address public admin;
    address public manager;
    address public treasury;

    /**
     * @notice Diamond Cut Callback function used by the diamond during tests
     * @dev This function must be implemented by all diamond test contracts
     * @param _diamond The diamond address
     * @param _cuts The facet cuts to apply
     * @param _init The init address
     * @param _calldata The calldata for initialization
     */
    function diamondCutCallback(
        address _diamond, 
        IDiamondCut.FacetCut[] memory _cuts, 
        address _init, 
        bytes memory _calldata
    ) external override {
        IDiamondCut(_diamond).diamondCut(_cuts, _init, _calldata);
    }
    
    /**
     * @notice Sets up the diamond and standard test addresses
     * @dev Override this in child contracts if needed, but call super.setUp() first
     */
    function setUp() public virtual {
        // Setup addresses
        admin = address(this);
        manager = address(0x1234);
        treasury = address(0x5678);
        
        // Deploy diamond
        diamond = payable(new DiamondDeployer().deployDiamond(admin).diamond);
        
        // Set up role for manager (if needed for tests)
        vm.startPrank(admin);
        AccessControlFacet(diamond).grantRole(LibAccessControl.MANAGER_ROLE, manager);
        vm.stopPrank();
        
        // Fast forward time for role acceptance
        vm.warp(block.timestamp + LibAccessControl.DEFAULT_GRANT_DELAY + 1);
        
        // Accept the role
        vm.prank(manager);
        AccessControlFacet(diamond).acceptRole(LibAccessControl.MANAGER_ROLE);
    }
    
    /**
     * @notice Implementation of IERC721Receiver
     * @return bytes4 The function selector
     */
    function onERC721Received(
        address, 
        address, 
        uint256, 
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
    
    /**
     * @notice Implementation of IERC1155Receiver for single token transfers
     * @return bytes4 The function selector
     */
    function onERC1155Received(
        address, 
        address, 
        uint256, 
        uint256, 
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC1155Received.selector;
    }
    
    /**
     * @notice Implementation of IERC1155Receiver for batch transfers
     * @return bytes4 The function selector
     */
    function onERC1155BatchReceived(
        address, 
        address, 
        uint256[] calldata, 
        uint256[] calldata, 
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
    
    /**
     * @notice Implementation of IERC165 interface detection
     * @param interfaceId The interface identifier to check
     * @return bool True if the interface is supported
     */
    function supportsInterface(
        bytes4 interfaceId
    ) external pure override returns (bool) {
        return
            interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(IERC721Receiver).interfaceId ||
            interfaceId == type(IERC1155Receiver).interfaceId;
    }
}
