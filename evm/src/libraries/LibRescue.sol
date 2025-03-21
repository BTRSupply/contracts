// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {LibAccessControl as AC} from "@libraries/LibAccessControl.sol";
import {BTRErrors as Errors, BTREvents as Events} from "@libraries/BTREvents.sol";
import {ErrorType, TokenType, Rescue, RescueRequest} from "@/BTRTypes.sol";
import {BTRStorage as S} from "@libraries/BTRStorage.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

library LibRescue {

    using SafeERC20 for IERC20;

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

    function getRescueRequest(
        address receiver,
        TokenType tokenType
    ) internal view returns (RescueRequest storage) {
        return S.rescue().rescueRequests[receiver][tokenType];
    }

    function getRescueStatus(address receiver, TokenType tokenType) internal view returns (uint8) {
        RescueRequest storage request = getRescueRequest(receiver, tokenType);
        uint64 timestamp = request.timestamp;
        
        if (timestamp == 0) {
            return 0; // No rescue request
        } else if (block.timestamp < (timestamp + S.rescue().rescueTimelock)) {
            return 1; // Locked
        } else if (block.timestamp <= (timestamp + S.rescue().rescueTimelock + S.rescue().rescueValidity)) {
            return 2; // Unlocked and valid
        } else {
            return 3; // Expired
        }
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
        Rescue storage rs = S.rescue();
        rs.rescueTimelock = DEFAULT_RESCUE_TIMELOCK;
        rs.rescueValidity = DEFAULT_RESCUE_VALIDITY;
    }

    function setRescueConfig(uint64 timelock, uint64 validity) internal {
        if (timelock < MIN_RESCUE_TIMELOCK || timelock > MAX_RESCUE_TIMELOCK ||
            validity < MIN_RESCUE_VALIDITY || validity > MAX_RESCUE_VALIDITY) {
            revert Errors.OutOfRange(timelock, MIN_RESCUE_TIMELOCK, MAX_RESCUE_TIMELOCK);
        }

        Rescue storage rs = S.rescue();
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
        requestRescue(TokenType.NATIVE, values);
    }

    function requestRescueERC20(address[] memory tokens) internal {
        if (tokens.length == 0) revert Errors.InvalidParameter();
        
        bytes32[] memory values = new bytes32[](tokens.length);
        for (uint256 i = 0; i < tokens.length;) {
            values[i] = bytes32(uint256(uint160(tokens[i])));
            unchecked { ++i; }
        }
        
        requestRescue(TokenType.ERC20, values);
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

    function requestRescue(TokenType tokenType, bytes32[] memory tokens) internal {
        // Create rescue request
        Rescue storage rs = S.rescue();
        RescueRequest storage request = rs.rescueRequests[msg.sender][tokenType];
        request.timestamp = uint64(block.timestamp);
        request.receiver = msg.sender;
        request.tokenType = tokenType;
        request.tokens = tokens;
        emit Events.RescueRequested(msg.sender, request.timestamp, tokenType, tokens);
    }

    function requestRescueAll() internal {
        requestRescue(TokenType.NATIVE, new bytes32[](0));
        requestRescue(TokenType.ERC20, new bytes32[](0));
        requestRescue(TokenType.ERC721, new bytes32[](0));
        requestRescue(TokenType.ERC1155, new bytes32[](0));
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                     EXECUTE/CANCEL RESCUES                     ║
    ╚═══════════════════════════════════════════════════════════════*/

    function rescue(
        address receiver,
        TokenType tokenType
    ) internal {
        Rescue storage rs = S.rescue();
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

    function cancelRescue(
        address receiver,
        TokenType tokenType
    ) internal {
        // Check if token is valid
        if (receiver == address(0)) {
            revert Errors.ZeroAddress();
        }

        // Get rescue request
        Rescue storage rs = S.rescue();
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

        emit Events.RescueCancelled(receiver, tokenType, new bytes32[](0));
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
        if (balance == 0) revert Errors.ZeroValue();
        
        (bool success, ) = receiver.call{value: balance}("");
        if (!success) revert Errors.Failed(ErrorType.TRANSFER);
        
        emit Events.RescueExecuted(ETH_ADDRESS, receiver, balance, TokenType.NATIVE);
    }

    function rescueERC20(bytes32[] storage tokens, address receiver) private {
        uint256 totalValue = 0;
        
        for (uint256 i = 0; i < tokens.length;) {
            address token = address(uint160(uint256(tokens[i])));
            if (token == address(0)) continue;
            
            IERC20 erc20 = IERC20(token);
            uint256 balance = erc20.balanceOf(address(this));
            
            if (balance > 0) {
                erc20.safeTransfer(receiver, balance);
                totalValue += balance;
                
                emit Events.RescueExecuted(token, receiver, balance, TokenType.ERC20);
            }
            unchecked { ++i; }
        }
        
        if (totalValue == 0) revert Errors.ZeroValue();
    }

    function rescueNFTs(address token, TokenType tokenType, address receiver, bytes32[] storage ids) private {
        uint256 count = 0;
        
        for (uint256 i = 0; i < ids.length;) {
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
            unchecked { ++i; }
        }
        if (count == 0) revert Errors.Failed(ErrorType.RESCUE);
        emit Events.RescueExecuted(token, receiver, count, tokenType);
    }
}
