// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC721} from "@openzeppelin/token/ERC721/IERC721.sol";
import {IERC165} from "@openzeppelin/utils/introspection/IERC165.sol";

interface IUniV4AllowanceTransfer {
    struct PermitDetails {
        address token;
        uint160 amount;
        uint48 expiration;
        uint48 nonce;
    }
    
    struct PermitSingle {
        PermitDetails details;
        address spender;
        uint256 sigDeadline;
    }
    
    struct PermitBatch {
        PermitDetails[] details;
        address spender;
        uint256 sigDeadline;
    }
}

interface IUniV4ERC721PermitV4 is IERC721 { // already implements IERC165
    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function nonces(address owner, uint256 word) external view returns (uint256 bitmap);
    function permit(address spender, uint256 tokenId, uint256 deadline, uint256 nonce, bytes memory signature) external payable;
    function permit(address owner, IUniV4AllowanceTransfer.PermitSingle memory permitSingle, bytes memory signature) external payable returns (bytes memory err);
    function permit2() external view returns (IUniV4AllowanceTransfer);
    function permitBatch(address owner, IUniV4AllowanceTransfer.PermitBatch memory _permitBatch, bytes memory signature) external payable returns (bytes memory err);
    function permitForAll(address owner, address operator, bool approved, uint256 deadline, uint256 nonce, bytes memory signature) external payable;
    function revokeNonce(uint256 nonce) external payable;
    function ownerOf(uint256 id) external view returns (address owner);
}
