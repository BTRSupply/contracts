// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {BTRDiamond} from "./BTRDiamond.sol";
import {DiamondCutFacet} from "./facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "./facets/DiamondLoupeFacet.sol";
import {AccessControlFacet} from "./facets/AccessControlFacet.sol";
import {IDiamondCut} from "./interfaces/IDiamondCut.sol";
import {BTRErrors as Errors, BTREvents as Events} from "./libraries/BTREvents.sol";
import {LibAccessControl} from "./libraries/LibAccessControl.sol";

/// @title BTRFactory
/// @dev Factory for deploying new BTR vaults with diamond pattern
contract BTRFactory {
  // Events
  event VaultCreated(address indexed vault, address owner);
  
  // Function selectors for facets
  struct FacetSelectors {
    address facetAddress;
    bytes4[] selectors;
  }
  
  // Admin of the factory
  address public immutable admin;
  
  // Facet addresses - deployed once and shared across all vaults
  address public immutable diamondCutFacet;
  address public immutable diamondLoupeFacet;
  address public immutable erc20Facet;
  address public immutable erc4626Facet;
  address public immutable vaultFacet;
  address public immutable ownershipFacet;
  address public immutable accessControlFacet;
  
  // Cached facet cuts to avoid recomputing for each vault
  IDiamondCut.FacetCut[] private facetCuts;
  
  constructor() {
    admin = msg.sender;

    // Deploy all facets once
    diamondCutFacet = address(new DiamondCutFacet());
    diamondLoupeFacet = address(new DiamondLoupeFacet());
    erc20Facet = address(new ERC20Facet());
    erc4626Facet = address(new ERC4626Facet());
    vaultFacet = address(new VaultFacet());
    accessControlFacet = address(new AccessControlFacet());
    
    // Pre-compute facet cuts to reuse for all vaults
    facetCuts = new IDiamondCut.FacetCut[](6);
    
    // DiamondLoupeFacet
    facetCuts[0] = IDiamondCut.FacetCut({
      facetAddress: diamondLoupeFacet,
      action: IDiamondCut.FacetCutAction.Add,
      functionSelectors: getFunctionSelectors("DiamondLoupeFacet")
    });
    
    // AccessControlFacet
    facetCuts[4] = IDiamondCut.FacetCut({
      facetAddress: accessControlFacet,
      action: IDiamondCut.FacetCutAction.Add,
      functionSelectors: getFunctionSelectors("AccessControlFacet")
    });
  }
  
  /// @notice Create a new BTR Vault
  /// @param _owner Owner of the vault
  /// @param _managers Array of manager addresses
  /// @param _keepers Array of keeper addresses
  /// @return vault Address of the new vault
  function createVault(
    address _owner,
    address[] calldata _managers,
    address[] calldata _keepers
  ) external returns (address vault) {
    // Only deploy the diamond proxy, not the facets
    BTRDiamond diamond = new BTRDiamond(_owner, diamondCutFacet);
    vault = address(diamond);
    
    // Call diamondCut to add the pre-deployed facets
    DiamondCutFacet(vault).diamondCut(facetCuts, address(0), "");
    
    // Initialize AccessControl facet
    (bool success, ) = vault.call(
        abi.encodeWithSelector(AccessControlFacet.initialize.selector, _owner)
    );
    require(success, "AccessControl initialization failed");
    
    // Set up managers
    for (uint256 i = 0; i < _managers.length; i++) {
        (success, ) = vault.call(
            abi.encodeWithSelector(
                AccessControlFacet.grantRole.selector,
                LibAccessControl.MANAGER_ROLE,
                _managers[i]
            )
        );
        require(success, "Manager role grant failed");
    }
    
    // Set up keepers
    for (uint256 i = 0; i < _keepers.length; i++) {
        (success, ) = vault.call(
            abi.encodeWithSelector(
                AccessControlFacet.grantRole.selector,
                LibAccessControl.KEEPER_ROLE,
                _keepers[i]
            )
        );
        require(success, "Keeper role grant failed");
    }
    
    emit VaultCreated(vault, _owner);
  }
  
  // Helper to get function selectors - calculated once per facet
  function getFunctionSelectors(string memory _facetName) internal pure returns (bytes4[] memory) {
    if (keccak256(bytes(_facetName)) == keccak256(bytes("DiamondLoupeFacet"))) {
      bytes4[] memory selectors = new bytes4[](5);
      selectors[0] = bytes4(keccak256("facets()"));
      selectors[1] = bytes4(keccak256("facetFunctionSelectors(address)"));
      selectors[2] = bytes4(keccak256("facetAddresses()"));
      selectors[3] = bytes4(keccak256("facetAddress(bytes4)"));
      selectors[4] = bytes4(keccak256("supportsInterface(bytes4)"));
      return selectors;
    } 
    else if (keccak256(bytes(_facetName)) == keccak256(bytes("AccessControlFacet"))) {
      bytes4[] memory selectors = new bytes4[](8);
      selectors[0] = bytes4(keccak256("hasRole(bytes32,address)"));
      selectors[1] = bytes4(keccak256("getRoleAdmin(bytes32)"));
      selectors[2] = bytes4(keccak256("setRoleAdmin(bytes32,bytes32)"));
      selectors[3] = bytes4(keccak256("grantRole(bytes32,address)"));
      selectors[4] = bytes4(keccak256("acceptRole(bytes32)"));
      selectors[5] = bytes4(keccak256("cancelRoleGrant(bytes32,address)"));
      selectors[6] = bytes4(keccak256("revokeRole(bytes32,address)"));
      selectors[7] = bytes4(keccak256("setTimelockConfig(uint256,uint256)"));
      return selectors;
    }
    
    revert Errors.InvalidFacetName();
  }
} 