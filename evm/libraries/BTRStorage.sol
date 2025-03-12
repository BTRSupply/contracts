// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {
  DiamondStorage, 
  AccessControlStorage, 
  VaultStorage, 
  ProtocolStorage,
  SwapperStorage,
  RescueStorage,
  AddressType,
  AccountStatus
} from "../BTRTypes.sol";

/// @title BTR Centralized Storage
/// @dev Contains storage accessors for BTR contract facets
library BTRStorage {

  /*═══════════════════════════════════════════════════════════════╗
  ║                       STORAGE POSITIONS                        ║
  ╚═══════════════════════════════════════════════════════════════*/

  // Storage positions - each must be unique
  bytes32 constant DIAMOND_STORAGE_SLOT = keccak256("btr.diamond");
  bytes32 constant VAULT_STORAGE_SLOT = keccak256("btr.vault");
  bytes32 constant ACCESS_CONTROL_STORAGE_SLOT = keccak256("btr.access-control");
  bytes32 constant MANAGEMENT_STORAGE_SLOT = keccak256("btr.management");
  bytes32 constant SWAPPER_STORAGE_SLOT = keccak256("btr.swapper");
  bytes32 constant RESCUE_STORAGE_SLOT = keccak256("btr.vault.rescue.storage");

  /*═══════════════════════════════════════════════════════════════╗
  ║                       STORAGE ACCESSORS                        ║
  ╚═══════════════════════════════════════════════════════════════*/

  /// @dev Access diamond storage
  function diamond() internal pure returns (DiamondStorage storage ds) {
    bytes32 position = DIAMOND_STORAGE_SLOT;
    assembly {
      ds.slot := position
    }
  }

  /// @dev Access vault storage
  function vault() internal pure returns (VaultStorage storage vs) {
    bytes32 position = VAULT_STORAGE_SLOT;
    assembly {
      vs.slot := position
    }
  }

  /// @dev Access access control storage
  function accessControl() internal pure returns (AccessControlStorage storage acs) {
    bytes32 position = ACCESS_CONTROL_STORAGE_SLOT;
    assembly {
      acs.slot := position
    }
  }

  /// @dev Access management storage
  function protocol() internal pure returns (ProtocolStorage storage ms) {
    bytes32 position = MANAGEMENT_STORAGE_SLOT;
    assembly {
      ms.slot := position
    }
  }
  
  /// @dev Access swapper storage
  function swapper() internal pure returns (SwapperStorage storage ss) {
    bytes32 position = SWAPPER_STORAGE_SLOT;
    assembly {
      ss.slot := position
    }
  }
  
  /// @dev Access rescue storage
  function rescue() internal pure returns (RescueStorage storage rs) {
    bytes32 position = RESCUE_STORAGE_SLOT;
    assembly {
      rs.slot := position
    }
  }
  
  /// @dev Combined accessor for vault storage (for backward compatibility)
  function btrStorage() internal pure returns (VaultStorage storage) {
    return vault();
  }
} 