// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BTRErrors as Errors, BTREvents as Events} from "@libraries/BTREvents.sol";
import {BTRStorage as S} from "@libraries/BTRStorage.sol";
import {BTRUtils} from "@libraries/BTRUtils.sol";
import {ErrorType, CoreStorage, ALMVault} from "@/BTRTypes.sol";
import {LibERC1155} from "@libraries/LibERC1155.sol";
import {RestrictedFacet} from "@facets/abstract/RestrictedFacet.sol";
import {PausableFacet} from "@facets/abstract/PausableFacet.sol";
import {NonReentrantFacet} from "@facets/abstract/NonReentrantFacet.sol";

// NB: vault existence is handled in the .getVault() function
// no need for a ifVaultExists modifier
abstract contract ERC1155Facet is RestrictedFacet, PausableFacet, NonReentrantFacet {
    using SafeERC20 for IERC20;
    using BTRUtils for uint32;
    using LibERC1155 for uint32;

    function totalSupply(uint32 id) external view returns (uint256) {
        return id.totalSupply();
    }

    function balanceOf(
        uint32 id,
        address account
    ) external view returns (uint256) {
        return id.balanceOf(account);
    }

    function allowance(
        uint32 id,
        address owner,
        address spender
    ) external view returns (uint256) {
        return id.allowance(owner, spender);
    }

    function _approve(uint32 id, address spender, uint256 amount) internal {
        id.approve(msg.sender, spender, amount);
    }

    function _mint(
        uint32 id,
        address account,
        uint256 amount
    ) internal
        whenVaultNotPaused(id)
        onlyUnrestrictedMinter(id, account)
    {
        id.mint(account, amount);
    }

    function _burn(
        uint32 id,
        address account,
        uint256 amount
    ) internal
        whenVaultNotPaused(id)
        onlyUnrestrictedMinter(id, account)
    {
        id.burn(account, amount);
    }

    function transfer(
        uint32 id,
        address recipient,
        uint256 amount
    )
        external
        whenVaultNotPaused(id)
        onlyNotBlacklisted(id, msg.sender)
        onlyUnrestrictedMinter(id, recipient)
        returns (bool)
    {
        id.transfer(msg.sender, recipient, amount);
        return true;
    }

    function transferFrom(
        uint32 id,
        address sender,
        address recipient,
        uint256 amount
    )
        external
        whenVaultNotPaused(id)
        onlyUnrestrictedMinter(id, recipient)
        returns (bool)
    {
        id.transferFrom(msg.sender, sender, recipient, amount);
        return true;
    }
}
