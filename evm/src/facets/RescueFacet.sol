// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {LibAccessControl as AC} from "@libraries/LibAccessControl.sol";
import {LibRescue as R} from "@libraries/LibRescue.sol";
import {BTRErrors as Errors, BTREvents as Events} from "@libraries/BTREvents.sol";
import {PermissionedFacet} from "@facets/abstract/PermissionedFacet.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {BTRStorage as S} from "@libraries/BTRStorage.sol";
import {TokenType, ErrorType, Rescue} from "@/BTRTypes.sol";

contract RescueFacet is PermissionedFacet, IERC721Receiver, IERC1155Receiver {

    /*═══════════════════════════════════════════════════════════════╗
    ║                             VIEWS                              ║
    ╚═══════════════════════════════════════════════════════════════*/

    function getRescueRequest(address receiver, TokenType tokenType) external view returns (
        uint64 timestamp
    ) {
        return R.getRescueRequest(receiver, tokenType).timestamp;
    }

    function getRescueStatus(address receiver, TokenType tokenType) external view returns (uint8) {
        return R.getRescueStatus(receiver, tokenType);
    }

    function isRescueLocked(address receiver, TokenType tokenType) external view returns (bool) {
        return R.isRescueLocked(receiver, tokenType);
    }

    function isRescueExpired(address receiver, TokenType tokenType) external view returns (bool) {
        return R.isRescueExpired(receiver, tokenType);
    }

    function isRescueUnlocked(address receiver, TokenType tokenType) external view returns (bool) {
        return R.isRescueUnlocked(receiver, tokenType);
    }

    function getRescueConfig() external view returns (uint64 timelock, uint64 validity) {
        Rescue storage rs = S.rescue();
        return (rs.rescueTimelock, rs.rescueValidity);
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                       RESCUE REQUESTS                          ║
    ╚═══════════════════════════════════════════════════════════════*/

    function requestRescueNative() external onlyAdmin {
        R.requestRescueNative();
    }

    function requestRescueERC20(address[] calldata tokens) external onlyAdmin {
        if (tokens.length == 0) revert Errors.InvalidParameter();
        R.requestRescueERC20(tokens);
    }

    function requestRescueERC721(uint256 id) external onlyAdmin {
        R.requestRescueERC721(id);
    }

    function requestRescueERC721(bytes32[] calldata ids) external onlyAdmin {
        R.requestRescueERC721(ids);
    }

    function requestRescueERC1155(uint256 id) external onlyAdmin {
        R.requestRescueERC1155(id);
    }

    function requestRescueERC1155(bytes32[] calldata ids) external onlyAdmin {
        R.requestRescueERC1155(ids);
    }

    function requestRescueAll() external onlyAdmin {
        R.requestRescueAll();
    }

    function rescue(address receiver, TokenType tokenType) external onlyManager {
        R.rescue(receiver, tokenType);
    }

    function rescueAll(address receiver) external onlyManager {
        R.rescueAll(receiver);
    }

    function cancelRescue(address receiver, TokenType tokenType) external {
        R.cancelRescue(receiver, tokenType);
    }

    function cancelRescueAll(address receiver) external {
        R.cancelRescueAll(receiver);
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                      RECEIVER INTERFACES                       ║
    ╚═══════════════════════════════════════════════════════════════*/

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return 
            interfaceId == type(IERC165).interfaceId ||
            interfaceId == type(IERC721Receiver).interfaceId ||
            interfaceId == type(IERC1155Receiver).interfaceId;
    }

    receive() external payable {}

    /*═══════════════════════════════════════════════════════════════╗
    ║                         CONFIGURATION                          ║
    ╚═══════════════════════════════════════════════════════════════*/

    function setRescueConfig(uint64 timelock, uint64 validity) external onlyAdmin {
        R.setRescueConfig(timelock, validity);
    }

    function initialize() external {
        R.initialize();
    }
}
