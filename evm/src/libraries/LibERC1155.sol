// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BTRErrors as Errors, BTREvents as Events} from "@libraries/BTREvents.sol";
import {BTRStorage as S} from "@libraries/BTRStorage.sol";
import {BTRUtils} from "@libraries/BTRUtils.sol";
import {ErrorType, CoreStorage, ALMVault} from "@/BTRTypes.sol";

library LibERC1155 {
    using SafeERC20 for IERC20;
    using BTRUtils for uint32;

    function totalSupply(uint32 id) internal view returns (uint256) {
        return id.getVault().totalSupply;
    }

    function balanceOf(uint32 id, address account) internal view returns (uint256) {
        return id.getVault().balances[account];
    }
    
    function allowance(uint32 id, address owner, address spender) internal view returns (uint256) {
        return id.getVault().allowances[owner][spender];
    }

    function approve(uint32 id, address owner, address spender, uint256 amount) internal {
        if (spender == address(0)) revert Errors.ZeroAddress();
        id.getVault().allowances[owner][spender] = amount;
        emit Events.Approval(owner, spender, amount);
    }

    function transferFrom(uint32 id, address operator, address sender, address recipient, uint256 amount) internal {
        ALMVault storage vs = id.getVault();

        if (sender != operator) {
            uint256 currentAllowance = vs.allowances[sender][operator];
            if (currentAllowance < amount) {
                revert Errors.Insufficient(currentAllowance, amount);
            }
            vs.allowances[sender][operator] = currentAllowance - amount;
        }
        
        transfer(id, sender, recipient, amount);
    }

    function transfer(uint32 id, address sender, address recipient, uint256 amount) internal {
        if (sender == address(0) || recipient == address(0)) revert Errors.ZeroAddress();
        if (amount == 0) revert Errors.ZeroValue();
        
        ALMVault storage vs = id.getVault();
        
        if (vs.balances[sender] < amount) {
            revert Errors.Insufficient(vs.balances[sender], amount);
        }
        
        vs.balances[sender] -= amount;
        vs.balances[recipient] += amount;
        
        emit Events.Transfer(sender, recipient, amount);
    }

    function mint(uint32 id, address account, uint256 amount) internal {
        if (account == address(0)) revert Errors.ZeroAddress();
        
        ALMVault storage vs = id.getVault();
        
        if (vs.maxSupply > 0 && vs.totalSupply + amount > vs.maxSupply) {
            revert Errors.Exceeds(vs.totalSupply + amount, vs.maxSupply);
        }
        
        vs.totalSupply += amount;
        vs.balances[account] += amount;
        
        emit Events.Transfer(address(0), account, amount);
    }

    function burn(uint32 id, address account, uint256 amount) internal {
        if (account == address(0)) revert Errors.ZeroAddress();
        
        ALMVault storage vs = id.getVault();
        
        if (vs.balances[account] < amount) {
            revert Errors.Insufficient(vs.balances[account], amount);
        }
        
        vs.totalSupply -= amount;
        vs.balances[account] -= amount;
        
        emit Events.Transfer(account, address(0), amount);
    }
}
