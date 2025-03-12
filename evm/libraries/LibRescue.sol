// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20Metadata} from "@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {LibAccessControl as AC} from "./LibAccessControl.sol";
import {BTRErrors as Errors, BTREvents as Events} from "./BTREvents.sol";
import {ErrorType, TokenType, RescueStorage, RescueRequest} from "../BTRTypes.sol";
import {BTRStorage as S} from "./BTRStorage.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

library LibRescue {

    using SafeERC20 for IERC20Metadata;

    /*═══════════════════════════════════════════════════════════════╗
    ║                           CONSTANTS                            ║
    ╚═══════════════════════════════════════════════════════════════*/

    uint64 public constant DEFAULT_RESCUE_TIMELOCK = 2 days;
    uint64 public constant DEFAULT_RESCUE_VALIDITY = 7 days;
    uint64 public constant MIN_RESCUE_TIMELOCK = 1 days;
    uint64 public constant MAX_RESCUE_TIMELOCK = 7 days;
    uint64 public constant MIN_RESCUE_VALIDITY = 1 days;
    uint64 public constant MAX_RESCUE_VALIDITY = 30 days;

    // Special token address for native ETH
    address internal constant ETH_ADDRESS = address(1);

    /*═══════════════════════════════════════════════════════════════╗
    ║                             VIEWS                              ║
    ╚═══════════════════════════════════════════════════════════════*/

    function getRescueRequest(address receiver, TokenType tokenType) internal view returns (
        uint64 timestamp,
        uint8 status
    ) {
        RescueStorage storage rs = S.rescue();
        RescueRequest storage req = rs.rescueRequests[receiver][tokenType];
        timestamp = req.timestamp;
        
        if (req.timestamp == 0) {
            status = 0; // No rescue request
        } else if (block.timestamp < (req.timestamp + rs.rescueTimelock)) {
            status = 1; // Locked
        } else if (block.timestamp <= (req.timestamp + rs.rescueTimelock + rs.rescueValidity)) {
            status = 2; // Unlocked and valid
        } else {
            status = 3; // Expired
        }
    }

    function getRescueStatus(address receiver, TokenType tokenType) internal view returns (uint8) {
        (uint64 timestamp, uint8 status) = getRescueRequest(receiver, tokenType);
        return status;
    }

    function isRescueLocked(address receiver, TokenType tokenType) internal view returns (bool) {
        return getRescueStatus(receiver, tokenType) == 1; // 1 = locked
    }

    function isRescueExpired(address receiver, TokenType tokenType) internal view returns (bool) {
        return getRescueStatus(receiver, tokenType) == 3; // 3 = expired
    }

    function isRescueUnlocked(address receiver, TokenType tokenType) internal view returns (bool) {
        return getRescueStatus(receiver, tokenType) == 2; // 2 = unlocked and valid
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                          CONFIGURATION                         ║
    ╚═══════════════════════════════════════════════════════════════*/

    function initialize() internal {
        RescueStorage storage rs = S.rescue();
        rs.rescueTimelock = DEFAULT_RESCUE_TIMELOCK;
        rs.rescueValidity = DEFAULT_RESCUE_VALIDITY;
    }

    function setRescueConfig(uint64 timelock, uint64 validity) internal {
        if (timelock < MIN_RESCUE_TIMELOCK || timelock > MAX_RESCUE_TIMELOCK ||
            validity < MIN_RESCUE_VALIDITY || validity > MAX_RESCUE_VALIDITY) {
            revert Errors.OutOfRange(timelock, MIN_RESCUE_TIMELOCK, MAX_RESCUE_TIMELOCK);
        }

        RescueStorage storage rs = S.rescue();
        rs.rescueTimelock = timelock;
        rs.rescueValidity = validity;

        emit Events.RescueConfigUpdated(timelock, validity);
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                       RESCUE REQUESTS                          ║
    ╚═══════════════════════════════════════════════════════════════*/

    function requestRescueNative() internal {
        // For native ETH, we don't need specific values
        bytes32[] memory values = new bytes32[](0);
        requestRescue(ETH_ADDRESS, uint8(TokenType.NATIVE), values);
    }

    function requestRescueERC20(address[] memory tokens) internal {
        if (tokens.length == 0) revert Errors.InvalidParameter();
        
        bytes32[] memory values = new bytes32[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == address(0)) revert Errors.ZeroAddress();
            values[i] = bytes32(uint256(uint160(tokens[i])));
        }
        
        requestRescue(address(this), uint8(TokenType.ERC20), values);
    }

    function requestRescueERC721(uint256 id) internal {
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = bytes32(id);
        requestRescue(TokenType.ERC721, ids);
    }

    function requestRescueERC721(bytes32[] memory ids) internal {
        requestRescue(TokenType.ERC721, ids);
    }

    function requestRescueERC1155(uint256 id) internal {
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = bytes32(id);
        requestRescue(TokenType.ERC1155, ids);
    }

    function requestRescueERC1155(bytes32[] memory ids) internal {
        requestRescue(TokenType.ERC1155, ids);
    }

    function requestRescue(TokenType tokenType, bytes32[] memory tokens) private {
        // Check if token is valid
        if (tokenType != TokenType.NATIVE && tokens.length == 0) {
            revert Errors.InvalidParameter();
        }

        // Check if token is already being rescued
        RescueStorage storage rs = S.rescue();
        RescueRequest storage request = rs.rescueRequests[msg.sender][tokenType];

        if (request.timestamp != 0) {
            revert Errors.AlreadyExists(ErrorType.RESCUE);
        }

        // Create rescue request
        request.timestamp = uint64(block.timestamp);
        request.receiver = msg.sender;
        request.tokenType = tokenType;
        request.tokens = tokens;
        emit Events.RescueRequested(msg.sender, request.timestamp, tokenType, tokens);
    }

    function requestRescueAll() internal {
        requestRescue(TokenType.NATIVE);
        requestRescue(TokenType.ERC20);
        requestRescue(TokenType.ERC721);
        requestRescue(TokenType.ERC1155);
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                     EXECUTE/CANCEL RESCUES                     ║
    ╚═══════════════════════════════════════════════════════════════*/

    function rescue(address receiver, TokenType tokenType) internal {
        // Get rescue request
        RescueStorage storage rs = S.rescue();
        RescueRequest storage request = rs.rescueRequests[receiver][tokenType];

        // Check if rescue request exists
        if (request.timestamp == 0) {
            revert Errors.NotFound(ErrorType.RESCUE);
        }

        // Check if rescue is still locked
        if (block.timestamp < request.timestamp + rs.rescueTimelock) {
            revert Errors.Locked();
        }

        // Check if rescue has expired
        if (block.timestamp > request.timestamp + rs.rescueTimelock + rs.rescueValidity) {
            revert Errors.Expired(ErrorType.RESCUE);
        }

        // Execute the appropriate rescue based on token type
        if (tokenType == TokenType.NATIVE) {
            rescueNative(receiver);
        } else if (tokenType == TokenType.ERC20) {
            rescueERC20(request.tokens, receiver);
        } else if (tokenType == TokenType.ERC721 || tokenType == TokenType.ERC1155) {
            rescueNFTs(address(uint160(uint256(request.tokens[0]))), tokenType, receiver, request.tokens);
        } else {
            revert Errors.InvalidParameter();
        }

        // Clear rescue request
        delete rs.rescueRequests[msg.sender][tokenType];
    }

    function rescueAll(address receiver) internal {
        rescue(receiver, TokenType.NATIVE);
        rescue(receiver, TokenType.ERC20);
        rescue(receiver, TokenType.ERC721);
        rescue(receiver, TokenType.ERC1155);
    }

    function cancelRescue(address receiver, TokenType tokenType) internal {
        // Check if token is valid
        if (receiver == address(0)) {
            revert Errors.ZeroAddress();
        }

        // Get rescue request
        RescueStorage storage rs = S.rescue();
        RescueRequest storage request = rs.rescueRequests[receiver][tokenType];

        // Check if rescue request exists
        if (request.timestamp == 0) {
            revert Errors.NotFound(ErrorType.RESCUE);
        }

        // Check if caller is the requester or has admin role
        if (msg.sender != request.receiver && !AC.hasRole(AC.ADMIN_ROLE, msg.sender)) {
            revert Errors.Unauthorized(ErrorType.RESCUE);
        }

        // Clear rescue request
        delete rs.rescueRequests[receiver][tokenType];

        emit Events.RescueCancelled(receiver, tokenType);
    }

    function cancelRescueAll(address receiver) internal {
        cancelRescue(receiver, TokenType.NATIVE);
        cancelRescue(receiver, TokenType.ERC20);
        cancelRescue(receiver, TokenType.ERC721);
        cancelRescue(receiver, TokenType.ERC1155);
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                      INTERNAL FUNCTIONS                        ║
    ╚═══════════════════════════════════════════════════════════════*/

    function rescueNative(address receiver) private {
        uint256 balance = address(this).balance;
        if (balance == 0) revert Errors.ZeroAmount();
        
        (bool success, ) = receiver.call{value: balance}("");
        if (!success) revert Errors.TransferFailed();
        
        emit Events.RescueExecuted(ETH_ADDRESS, receiver, balance);
    }

    function rescueERC20(bytes32[] storage tokens, address receiver) private {
        uint256 totalValue = 0;
        
        for (uint256 i = 0; i < tokens.length; i++) {
            address token = address(uint160(uint256(tokens[i])));
            if (token == address(0)) continue;
            
            IERC20Metadata erc20 = IERC20Metadata(token);
            uint256 balance = erc20.balanceOf(address(this));
            
            if (balance > 0) {
                erc20.safeTransfer(receiver, balance);
                totalValue += balance;
                
                emit Events.RescueExecuted(token, receiver, balance);
            }
        }
        
        if (totalValue == 0) revert Errors.ZeroAmount();
    }

    function rescueNFTs(address token, TokenType tokenType, address receiver, bytes32[] storage ids) private {
        uint256 count = 0;
        
        for (uint256 i = 0; i < ids.length; i++) {
            uint256 tokenId = uint256(ids[i]);
            
            if (tokenType == TokenType.ERC721) {
                IERC721 erc721 = IERC721(token);
                try erc721.ownerOf(tokenId) returns (address owner) {
                    if (owner == address(this)) {
                        erc721.safeTransferFrom(address(this), receiver, tokenId);
                        count++;
                    }
                } catch {}
            } else if (tokenType == TokenType.ERC1155) {
                IERC1155 erc1155 = IERC1155(token);
                uint256 balance = erc1155.balanceOf(address(this), tokenId);
                
                if (balance > 0) {
                    try erc1155.safeTransferFrom(address(this), receiver, tokenId, balance, "") {
                        count++;
                    } catch {}
                }
            }
        }
        if (count == 0) revert Errors.Failed(ErrorType.RESCUE);
        emit Events.RescueExecuted(receiver, uint8(tokenType), ids, count);
    }
}
