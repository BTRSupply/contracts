// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {LibDiamond} from "@libraries/LibDiamond.sol";
import {LibAccessControl} from "@libraries/LibAccessControl.sol";
import {LibTreasury as T} from "@libraries/LibTreasury.sol";
import {PermissionedFacet} from "@facets/abstract/PermissionedFacet.sol";
import {Fees} from "@/BTRTypes.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TreasuryFacet is PermissionedFacet {

    /*═══════════════════════════════════════════════════════════════╗
    ║                            TREASURY                            ║
    ╚═══════════════════════════════════════════════════════════════*/

    /// @notice Initialize the facet
    /// @dev Can only be called once by admin
    function initializeTreasury() external onlyAdmin {
        // No initialization needed for TreasuryFacet
    }

    // protocol level fees
    function setFees(uint32 vaultId, Fees calldata fees) external onlyManager {
        T.setFees(vaultId, fees);
    }

    // protocol level fees
    function setFees(Fees calldata fees) external onlyManager {
        T.setFees(fees);
    }

    // protocol level default fees (used for new vaults)
    function setDefaultFees(Fees calldata fees) external onlyManager {
        T.setDefaultFees(fees);
    }

    // vault level fees
    function getFees(uint32 vaultId) external view returns (Fees memory) {
        return T.getFees(vaultId);
    }

    // protocol level fees
    function getFees() external view returns (Fees memory) {
        return T.getFees();
    }

    // protocol level fees
    function getAccruedFees(uint32 vaultId, IERC20 token) external view returns (uint256) {
        return T.getAccruedFees(vaultId, token);
    }

    // protocol level fees
    function getAccruedFees(IERC20 token) external view returns (uint256) {
        return T.getAccruedFees(token);
    }

    function getPendingFees(uint32 vaultId, IERC20 token) external view returns (uint256) {
        return T.getPendingFees(vaultId, token);
    }

    function setTreasury(address _treasury) external onlyAdmin {
        T.setTreasury(_treasury);
    }

    function getTreasury() external view returns (address) {
        return T.getTreasury();
    }
}
