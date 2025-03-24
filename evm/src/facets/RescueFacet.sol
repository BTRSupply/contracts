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
import {TokenType, ErrorType, Rescue, RescueRequest} from "@/BTRTypes.sol";

/**
 * @title RescueFacet
 * @notice Diamond facet for rescuing tokens accidentally sent to the contract
 * @dev Implements ERC721 and ERC1155 receiver interfaces to handle NFT transfers
 */
contract RescueFacet is PermissionedFacet, IERC721Receiver, IERC1155Receiver {

    /*═══════════════════════════════════════════════════════════════╗
    ║                             VIEWS                              ║
    ╚═══════════════════════════════════════════════════════════════*/

    /// @notice Initialize the rescue functionality
    /// @dev Can only be called once by admin
    function initializeRescue() external onlyAdmin {
        R.initialize();
    }

    /// @notice Get a rescue request's timestamp
    /// @param receiver The address that requested the rescue
    /// @param tokenType The type of token being rescued
    /// @return timestamp The timestamp when the rescue was requested
    /// @return tokenAddress The address of the token contract
    /// @return tokenIdsCount The number of token IDs in the request
    function getRescueRequest(address receiver, TokenType tokenType) external view returns (
        uint64 timestamp,
        address tokenAddress,
        uint256 tokenIdsCount
    ) {
        RescueRequest storage request = R.getRescueRequest(receiver, tokenType);
        return (request.timestamp, request.tokenAddress, request.tokenIds.length);
    }

    /// @notice Get the status of a rescue request
    /// @param receiver The address that requested the rescue
    /// @param tokenType The type of token being rescued
    /// @return Status code: 0=none, 1=locked, 2=unlocked, 3=expired
    function getRescueStatus(address receiver, TokenType tokenType) external view returns (uint8) {
        return R.getRescueStatus(receiver, tokenType);
    }

    /// @notice Check if a rescue request is locked
    /// @param receiver The address that requested the rescue
    /// @param tokenType The type of token being rescued
    /// @return True if the rescue is locked
    function isRescueLocked(address receiver, TokenType tokenType) external view returns (bool) {
        return R.isRescueLocked(receiver, tokenType);
    }

    /// @notice Check if a rescue request is expired
    /// @param receiver The address that requested the rescue
    /// @param tokenType The type of token being rescued
    /// @return True if the rescue is expired
    function isRescueExpired(address receiver, TokenType tokenType) external view returns (bool) {
        return R.isRescueExpired(receiver, tokenType);
    }

    /// @notice Check if a rescue request is unlocked and valid
    /// @param receiver The address that requested the rescue
    /// @param tokenType The type of token being rescued
    /// @return True if the rescue is unlocked and valid
    function isRescueUnlocked(address receiver, TokenType tokenType) external view returns (bool) {
        return R.isRescueUnlocked(receiver, tokenType);
    }

    /// @notice Get the current rescue configuration
    /// @return timelock The timelock period in seconds
    /// @return validity The validity period in seconds after the timelock ends
    function getRescueConfig() external view returns (uint64 timelock, uint64 validity) {
        Rescue storage rs = S.rescue();
        return (rs.rescueTimelock, rs.rescueValidity);
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                       RESCUE REQUESTS                          ║
    ╚═══════════════════════════════════════════════════════════════*/

    /// @notice Request to rescue native tokens
    /// @dev Only callable by admin
    function requestRescueNative() external onlyAdmin {
        R.requestRescueNative();
    }

    /// @notice Request to rescue ERC20 tokens
    /// @param tokens Array of ERC20 token addresses to rescue
    /// @dev Only callable by admin
    function requestRescueERC20(address[] calldata tokens) external onlyAdmin {
        if (tokens.length == 0) revert Errors.InvalidParameter();
        R.requestRescueERC20(tokens);
    }

    /// @notice Request to rescue a single ERC721 token
    /// @param tokenAddress The address of the NFT contract
    /// @param tokenId The token ID to rescue
    /// @dev Only callable by admin
    function requestRescueERC721(address tokenAddress, uint256 tokenId) external onlyAdmin {
        R.requestRescueERC721(tokenAddress, tokenId);
    }

    /// @notice Request to rescue multiple ERC721 tokens
    /// @param tokenAddress The address of the NFT contract
    /// @param tokenIds Array of token IDs to rescue
    /// @dev Only callable by admin
    function requestRescueERC721Batch(address tokenAddress, uint256[] calldata tokenIds) external onlyAdmin {
        bytes32[] memory ids = new bytes32[](tokenIds.length);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            ids[i] = bytes32(tokenIds[i]);
        }
        R.requestRescueERC721(tokenAddress, ids);
    }

    /// @notice Request to rescue a single ERC1155 token
    /// @param tokenAddress The address of the NFT contract 
    /// @param tokenId The token ID to rescue
    /// @dev Only callable by admin
    function requestRescueERC1155(address tokenAddress, uint256 tokenId) external onlyAdmin {
        R.requestRescueERC1155(tokenAddress, tokenId);
    }

    /// @notice Request to rescue multiple ERC1155 tokens
    /// @param tokenAddress The address of the NFT contract
    /// @param tokenIds Array of token IDs to rescue
    /// @dev Only callable by admin
    function requestRescueERC1155Batch(address tokenAddress, uint256[] calldata tokenIds) external onlyAdmin {
        bytes32[] memory ids = new bytes32[](tokenIds.length);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            ids[i] = bytes32(tokenIds[i]);
        }
        R.requestRescueERC1155(tokenAddress, ids);
    }

    /// @notice Execute a rescue request
    /// @param receiver The address that requested the rescue
    /// @param tokenType The type of token to rescue
    /// @dev Only callable by manager
    function rescue(address receiver, TokenType tokenType) external onlyManager {
        R.rescue(receiver, tokenType);
    }

    /// @notice Execute all rescue requests for a receiver
    /// @param receiver The address that requested the rescues
    /// @dev Only callable by manager
    function rescueAll(address receiver) external onlyManager {
        R.rescueAll(receiver);
    }

    /// @notice Cancel a rescue request
    /// @param receiver The address that requested the rescue
    /// @param tokenType The type of token to rescue
    function cancelRescue(address receiver, TokenType tokenType) external {
        // Verify that msg.sender is either the receiver or an admin
        if (msg.sender != receiver && !AC.hasRole(AC.ADMIN_ROLE, msg.sender)) {
            revert Errors.Unauthorized(ErrorType.RESCUE);
        }
        R.cancelRescue(receiver, tokenType);
    }

    /// @notice Cancel all rescue requests for a receiver
    /// @param receiver The address that requested the rescues
    function cancelRescueAll(address receiver) external {
        // Verify that msg.sender is either the receiver or an admin
        if (msg.sender != receiver && !AC.hasRole(AC.ADMIN_ROLE, msg.sender)) {
            revert Errors.Unauthorized(ErrorType.RESCUE);
        }
        R.cancelRescueAll(receiver);
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                      RECEIVER INTERFACES                       ║
    ╚═══════════════════════════════════════════════════════════════*/

    /// @notice Handle reception of ERC1155 tokens
    /// @dev Required for IERC1155Receiver compliance
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    /// @notice Handle reception of batched ERC1155 tokens
    /// @dev Required for IERC1155Receiver compliance
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    /// @notice Handle reception of ERC721 tokens
    /// @dev Required for IERC721Receiver compliance
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /// @notice Receive function to handle ETH transfers
    receive() external payable {}

    /*═══════════════════════════════════════════════════════════════╗
    ║                         CONFIGURATION                          ║
    ╚═══════════════════════════════════════════════════════════════*/

    /// @notice Set the rescue timelock and validity periods
    /// @param timelock The timelock period in seconds
    /// @param validity The validity period in seconds after the timelock ends
    /// @dev Only callable by admin
    function setRescueConfig(uint64 timelock, uint64 validity) external onlyAdmin {
        R.setRescueConfig(timelock, validity);
    }

    /// @notice IERC165 support
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return
            interfaceId == type(IERC721Receiver).interfaceId ||
            interfaceId == type(IERC1155Receiver).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }
}
