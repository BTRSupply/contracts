// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {BTRErrors as Errors, BTREvents as Events} from "../libraries/BTREvents.sol";
import {BTRStorage as S} from "../libraries/BTRStorage.sol";
import {BTRUtils} from "../libraries/BTRUtils.sol";
import {ErrorType, ProtocolStorage, VaultStorage} from "../BTRTypes.sol";
import {LibERC1155} from "../libraries/LibERC1155.sol";
import {ManagementFacet} from "./ManagementFacet.sol";

contract ERC1155VaultsFacet is ManagementFacet {
    using SafeERC20 for IERC20;
    using BTRUtils for uint32;
    using LibERC1155 for uint32;

    function balanceOf(uint32 vaultId, address account) external view returns (uint256) {
        VaultStorage storage vs = vaultId.getVaultStorage();
        return vs.balances[account];
    }

    function totalSupply(uint32 vaultId) external view returns (uint256) {
        VaultStorage storage vs = vaultId.getVaultStorage();
        return vs.totalSupply;
    }

    function approve(uint32 vaultId, address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert Errors.ZeroAddress();
        
        VaultStorage storage vs = vaultId.getVaultStorage();
        vs.allowances[msg.sender][spender] = amount;
        
        emit Events.Approval(msg.sender, spender, amount);
        return true;
    }

    function allowance(uint32 vaultId, address owner, address spender) external view returns (uint256) {
        VaultStorage storage vs = vaultId.getVaultStorage();
        return vs.allowances[owner][spender];
    }

    function _transfer(uint32 vaultId, address sender, address recipient, uint256 amount) internal whenVaultNotPaused(vaultId) {
        vaultId.transfer(sender, recipient, amount);
    }

    function _mint(uint32 vaultId, address account, uint256 amount) internal {
        vaultId.mint(account, amount);
    }

    function _burn(uint32 vaultId, address account, uint256 amount) internal {
        vaultId.burn(account, amount);
    }

    function transfer(uint32 vaultId, address recipient, uint256 amount) external returns (bool) {
        _transfer(vaultId, msg.sender, recipient, amount);
        return true;
    }

    function transferFrom(uint32 vaultId, address sender, address recipient, uint256 amount) external whenVaultNotPaused(vaultId) returns (bool) {
        vaultId.transferFrom(sender, recipient, amount);
        return true;
    }
}
