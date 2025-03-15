// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {
  Diamond, 
  AccessControl, 
  ALMVault, 
  CoreStorage,
  Rescue,
  Range,
  Treasury,
  Registry,
  Restrictions,
  Oracles,
  AddressType,
  AccountStatus
} from "@/BTRTypes.sol";

/// @title BTR Centralized Storage
/// @dev Contains storage accessors for BTR contract facets
library BTRStorage {

  /*═══════════════════════════════════════════════════════════════╗
  ║                       STORAGE POSITIONS                        ║
  ╚═══════════════════════════════════════════════════════════════*/

  // Storage positions - each must be unique
  bytes32 constant DIAMOND_NAMESPACE = keccak256("btr.diamond");
  bytes32 constant CORE_NAMESPACE = keccak256("btr.core");
  bytes32 constant RESCUE_STORAGE_SLOT = keccak256("btr.rescue");

  /*═══════════════════════════════════════════════════════════════╗
  ║                       STORAGE ACCESSORS                        ║
  ╚═══════════════════════════════════════════════════════════════*/

  /// @dev Access diamond storage
  function diamond() internal pure returns (Diamond storage ds) {
    bytes32 position = DIAMOND_NAMESPACE;
    assembly {
      ds.slot := position
    }
  }

  /// @dev Access core protocol storage
  function core() internal pure returns (CoreStorage storage cs) {
    bytes32 position = CORE_NAMESPACE;
    assembly {
      cs.slot := position
    }
  }

  /// @dev Access treasury storage
  function treasury() internal view returns (Treasury storage ts) {
    return core().treasury;
  }

  /// @dev Access access control storage
  function accessControl() internal view returns (AccessControl storage acs) {
    return core().accessControl;
  }

  /// @dev Access restriction storage
  function restrictions() internal view returns (Restrictions storage rs) {
    return core().restrictions;
  }

  /// @dev Access oracles storage
  function oracles() internal view returns (Oracles storage os) {
    return core().oracles;
  }

  /// @dev Access registry storage
  function registry() internal view returns (Registry storage rs) {
    return core().registry;
  }

  /// @dev Access rescue storage
  function rescue() internal pure returns (Rescue storage rs) {
    bytes32 position = RESCUE_STORAGE_SLOT;
    assembly {
      rs.slot := position
    }
  }
}
