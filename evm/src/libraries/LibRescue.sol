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

/// @title LibRescue
/// @notice Library for rescuing tokens accidentally sent to the contract
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

    /// @notice Get rescue storage pointer 
    function rs() internal pure returns (Rescue storage) {
        return S.rescue();
    }

    /// @notice Get a rescue request for a given receiver and token type
    /// @param receiver The address of the receiver
    /// @param tokenType The type of token being rescued
    /// @return The rescue request struct
    function getRescueRequest(address receiver, TokenType tokenType) internal view returns (
        RescueRequest storage
    ) {
        return rs().rescueRequests[receiver][tokenType];
    }

    /// @notice Check if a rescue request is valid
    /// @param receiver The address that requested the rescue
    /// @param tokenType The type of token being rescued
    /// @return Status code: 0=none, 1=locked, 2=unlocked, 3=expired
    function getRescueStatus(address receiver, TokenType tokenType) internal view returns (uint8) {
        RescueRequest storage request = getRescueRequest(receiver, tokenType);
        
        // Check if request exists
        if (request.timestamp == 0) return 0; // No request

        // Cache timelock and validity values to avoid multiple SLOAD operations
        uint64 timelock = rs().rescueTimelock;
        uint64 validity = rs().rescueValidity;
        
        uint64 unlockTime = request.timestamp + timelock;
        uint64 expiryTime = unlockTime + validity;
        
        uint64 currentTime = uint64(block.timestamp);
        if (currentTime < unlockTime) return 1; // Locked
        if (currentTime >= expiryTime) return 3; // Expired
        return 2; // Unlocked and valid
    }

    /// @notice Check if a rescue is locked, expired, or unlocked
    function isRescueLocked(address receiver, TokenType tokenType) internal view returns (bool) {
        return getRescueStatus(receiver, tokenType) == 1;
    }
    
    function isRescueExpired(address receiver, TokenType tokenType) internal view returns (bool) {
        return getRescueStatus(receiver, tokenType) == 3;
    }
    
    function isRescueUnlocked(address receiver, TokenType tokenType) internal view returns (bool) {
        return getRescueStatus(receiver, tokenType) == 2;
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                          CONFIGURATION                         ║
    ╚═══════════════════════════════════════════════════════════════*/

    /// @notice Initialize rescue functionality with default settings
    function initialize() internal {
        Rescue storage _rescue = rs();
        _rescue.rescueTimelock = DEFAULT_RESCUE_TIMELOCK;
        _rescue.rescueValidity = DEFAULT_RESCUE_VALIDITY;
    }

    /// @notice Set the timelock and validity periods for rescue requests
    function setRescueConfig(uint64 timelock, uint64 validity) internal {
        if (timelock < MIN_RESCUE_TIMELOCK || timelock > MAX_RESCUE_TIMELOCK ||
            validity < MIN_RESCUE_VALIDITY || validity > MAX_RESCUE_VALIDITY) {
            revert Errors.OutOfRange(timelock, MIN_RESCUE_TIMELOCK, MAX_RESCUE_TIMELOCK);
        }

        Rescue storage _rescue = rs();
        _rescue.rescueTimelock = timelock;
        _rescue.rescueValidity = validity;
        
        emit Events.RescueConfigUpdated(timelock, validity);
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                       RESCUE REQUESTS                          ║
    ╚═══════════════════════════════════════════════════════════════*/

    /// @notice Create a rescue request with necessary data
    function _createRescueRequest(
        address receiver,
        TokenType tokenType,
        address tokenAddress,
        bytes32[] memory tokenIds
    ) private {
        RescueRequest storage request = getRescueRequest(receiver, tokenType);
        
        // Create the rescue request
        request.timestamp = uint64(block.timestamp);
        request.receiver = receiver;
        request.tokenType = tokenType;
        request.tokenAddress = tokenAddress;
        
        // Store the token IDs
        delete request.tokenIds;
        
        // Copy tokenIds to storage - use unchecked to save gas on loop counters
        uint256 length = tokenIds.length;
        if (length > 0) {
            // Pre-allocate the array size to save gas
            request.tokenIds = new bytes32[](length);
            
            unchecked {
                for (uint256 i = 0; i < length; ++i) {
                    request.tokenIds[i] = tokenIds[i];
                }
            }
        }
        
        emit Events.RescueRequested(receiver, uint64(block.timestamp), tokenType, request.tokenIds);
    }

    /// @notice Request rescue for different token types
    function requestRescueNative() internal {
        _createRescueRequest(msg.sender, TokenType.NATIVE, ETH_ADDRESS, new bytes32[](0));
    }

    /// @notice Request rescue for ERC20 tokens (storing all tokens in tokenIds)
    /// @param tokenAddresses Array of ERC20 token addresses to rescue
    function requestRescueERC20(address[] memory tokenAddresses) internal {
        // Store all token addresses as bytes32 in tokenIds
        uint256 length = tokenAddresses.length;
        bytes32[] memory encodedAddresses = new bytes32[](length);
        
        unchecked {
            for (uint256 i = 0; i < length; ++i) {
                encodedAddresses[i] = bytes32(uint256(uint160(tokenAddresses[i])));
            }
        }
        
        // Create a single request with multiple tokens
        _createRescueRequest(msg.sender, TokenType.ERC20, address(0), encodedAddresses);
    }

    function requestRescueERC721(address tokenAddress, uint256 tokenId) internal {
        bytes32[] memory tokenIds = new bytes32[](1);
        tokenIds[0] = bytes32(tokenId);
        _createRescueRequest(msg.sender, TokenType.ERC721, tokenAddress, tokenIds);
    }
    
    function requestRescueERC721(address tokenAddress, bytes32[] memory tokenIds) internal {
        _createRescueRequest(msg.sender, TokenType.ERC721, tokenAddress, tokenIds);
    }

    function requestRescueERC1155(address tokenAddress, uint256 tokenId) internal {
        bytes32[] memory tokenIds = new bytes32[](1);
        tokenIds[0] = bytes32(tokenId);
        _createRescueRequest(msg.sender, TokenType.ERC1155, tokenAddress, tokenIds);
    }
    
    function requestRescueERC1155(address tokenAddress, bytes32[] memory tokenIds) internal {
        _createRescueRequest(msg.sender, TokenType.ERC1155, tokenAddress, tokenIds);
    }

    /// @notice Cancel rescue requests
    function cancelRescue(address receiver, TokenType tokenType) internal {
        RescueRequest storage request = getRescueRequest(receiver, tokenType);
        
        // Create copies for the event
        address tokenAddress = request.tokenAddress;
        uint256 length = request.tokenIds.length;
        bytes32[] memory tokenIdsCopy = new bytes32[](length);
        
        unchecked {
            for (uint256 i = 0; i < length; ++i) {
                tokenIdsCopy[i] = request.tokenIds[i];
            }
        }
        
        // Clear the rescue request
        delete rs().rescueRequests[receiver][tokenType];
        
        emit Events.RescueCancelled(receiver, tokenType, tokenIdsCopy);
    }

    function cancelRescueAll(address receiver) internal {
        cancelRescue(receiver, TokenType.NATIVE);
        cancelRescue(receiver, TokenType.ERC20);
        cancelRescue(receiver, TokenType.ERC721);
        cancelRescue(receiver, TokenType.ERC1155);
    }

    /*═══════════════════════════════════════════════════════════════╗
    ║                         EXECUTE RESCUE                         ║
    ╚═══════════════════════════════════════════════════════════════*/

    /// @notice Validate that a rescue can be executed
    function validateRescue(address receiver, TokenType tokenType) internal view {
        uint8 status = getRescueStatus(receiver, tokenType);
        
        if (status == 0) {
            revert Errors.NotFound(ErrorType.RESCUE);
        } else if (status == 1) {
            revert Errors.Locked();
        } else if (status == 3) {
            revert Errors.Expired(ErrorType.RESCUE);
        }
        // Status must be 2 (unlocked) to proceed
    }

    /// @notice Internal function to rescue a specific token type
    /// @dev Returns true if the rescue was successful
    function _rescueTokenType(address receiver, TokenType tokenType, bool validate) private returns (bool) {
        // Check status only if requested (optimized path for rescueAll)
        if (validate) {
            uint8 status = getRescueStatus(receiver, tokenType);
            if (status != 2) return false; // Only proceed if unlocked
        }
        
        // Get request data (once) and cache in memory
        RescueRequest storage request = getRescueRequest(receiver, tokenType);
        address tokenAddress = request.tokenAddress;
        uint256 tokenIdsLength = request.tokenIds.length;
        bool success = false;
        
        if (tokenType == TokenType.NATIVE) {
            // Rescue ETH
            uint256 balance = address(this).balance;
            if (balance > 0) {
                (bool sent,) = receiver.call{value: balance}("");
                if (sent) {
                    emit Events.RescueExecuted(ETH_ADDRESS, receiver, balance, TokenType.NATIVE);
                    success = true;
                }
            }
        } else if (tokenType == TokenType.ERC20) {
            // Rescue ERC20 tokens
            if (tokenIdsLength > 0) {
                // Multiple ERC20 tokens stored in tokenIds
                unchecked {
                    for (uint256 i = 0; i < tokenIdsLength; ++i) {
                        bytes32 tokenIdData = request.tokenIds[i];
                        address erc20Address = address(uint160(uint256(tokenIdData)));
                        if (erc20Address != address(0)) {
                            IERC20 token = IERC20(erc20Address);
                            uint256 balance = token.balanceOf(address(this));
                            if (balance > 0) {
                                IERC20(erc20Address).safeTransfer(receiver, balance);
                                emit Events.RescueExecuted(erc20Address, receiver, balance, TokenType.ERC20);
                                success = true;
                            }
                        }
                    }
                }
            } else if (tokenAddress != address(0)) {
                // Single ERC20 token in tokenAddress
                IERC20 token = IERC20(tokenAddress);
                uint256 balance = token.balanceOf(address(this));
                if (balance > 0) {
                    token.safeTransfer(receiver, balance);
                    emit Events.RescueExecuted(tokenAddress, receiver, balance, TokenType.ERC20);
                    success = true;
                }
            }
        } else if (tokenType == TokenType.ERC721) {
            // Rescue ERC721 tokens
            if (tokenAddress != address(0) && tokenIdsLength > 0) {
                IERC721 nft = IERC721(tokenAddress);
                unchecked {
                    for (uint256 i = 0; i < tokenIdsLength; ++i) {
                        uint256 tokenId = uint256(request.tokenIds[i]);
                        nft.safeTransferFrom(address(this), receiver, tokenId);
                        emit Events.RescueExecuted(tokenAddress, receiver, tokenId, TokenType.ERC721);
                        success = true;
                    }
                }
            }
        } else if (tokenType == TokenType.ERC1155) {
            // Rescue ERC1155 tokens
            if (tokenAddress != address(0) && tokenIdsLength > 0) {
                IERC1155 token = IERC1155(tokenAddress);
                unchecked {
                    for (uint256 i = 0; i < tokenIdsLength; ++i) {
                        uint256 tokenId = uint256(request.tokenIds[i]);
                        uint256 balance = token.balanceOf(address(this), tokenId);
                        if (balance > 0) {
                            token.safeTransferFrom(address(this), receiver, tokenId, balance, "");
                            emit Events.RescueExecuted(tokenAddress, receiver, tokenId, TokenType.ERC1155);
                            success = true;
                        }
                    }
                }
            }
        }
        
        // Clear the rescue request if any rescue was successful or we're validating
        if (success || validate) {
            delete rs().rescueRequests[receiver][tokenType];
        }
        
        return success;
    }

    /// @notice Execute rescue for all token types
    function rescueAll(address receiver) internal {
        // Only attempt rescues for requests that exist and are unlocked
        // This avoids unnecessary gas consumption
        uint8 nativeStatus = getRescueStatus(receiver, TokenType.NATIVE);
        uint8 erc20Status = getRescueStatus(receiver, TokenType.ERC20);
        uint8 erc721Status = getRescueStatus(receiver, TokenType.ERC721);
        uint8 erc1155Status = getRescueStatus(receiver, TokenType.ERC1155);
        
        if (nativeStatus == 2) _rescueTokenType(receiver, TokenType.NATIVE, false);
        if (erc20Status == 2) _rescueTokenType(receiver, TokenType.ERC20, false);
        if (erc721Status == 2) _rescueTokenType(receiver, TokenType.ERC721, false);
        if (erc1155Status == 2) _rescueTokenType(receiver, TokenType.ERC1155, false);
    }

    /// @notice Execute a rescue operation for a specific token type
    function rescue(address receiver, TokenType tokenType) internal {
        validateRescue(receiver, tokenType);
        bool success = _rescueTokenType(receiver, tokenType, false);
        
        if (!success) {
            // Clear the request even if rescue failed - it was validated
            delete rs().rescueRequests[receiver][tokenType];
        }
    }
}
