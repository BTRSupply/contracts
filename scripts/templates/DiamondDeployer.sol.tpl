// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// Core imports
import {BTRDiamond} from "@/BTRDiamond.sol";
import {IDiamondCut, IDiamondLoupe, IDiamondInit, IDiamondCutCallback} from "@interfaces/IDiamond.sol";
import {IERC173} from "@interfaces/ercs/IERC173.sol";
import {IERC165} from "@interfaces/ercs/IERC165.sol";
import {ICreateX} from "@interfaces/ICreateX.sol";
import {LibAccessControl} from "@libraries/LibAccessControl.sol";

// Facet imports
{{ facet_imports }}

// Diamond initializer contract to avoid stack too deep errors
contract DiamondInit {
    function init(address admin) external {
        // Since we'll be using delegatecall from the admin account via the diamond, 
        // we need to grant all necessary roles to the admin first to ensure they have permissions
        
        // Direct access to storage to grant roles 
        // These functions directly interact with storage so they don't use onlyAdmin checks
        LibAccessControl.grantRole(LibAccessControl.ADMIN_ROLE, admin);
        LibAccessControl.grantRole(LibAccessControl.MANAGER_ROLE, admin);
        LibAccessControl.grantRole(LibAccessControl.TREASURY_ROLE, admin);
        
        // Now that the admin has all roles, we can initialize all the facets
        {{ facet_initializations }}
    }
}

contract DiamondDeployer is IDiamondCutCallback {
    // Store admin address for diamondCutCallback
    address private _admin;

    /// @notice Deployment result containing all deployed contracts
    struct Deployment {
        address diamond;
        address[] facets;
        string[] facetNames;
    }

    /// @notice Deployment addresses for deterministic deployment
    struct DeploymentAddresses {
        address diamond;
        {{ deployment_addresses_fields }}
    }

    /// @notice Salts for deterministic deployment
    struct Salts {
        bytes32 diamond;
        {{ salts_fields }}
    }

    {{ selector_functions }}

    /**
     * @notice Diamond Cut Callback for authorization in diamond cut operations
     * @dev This function is implemented for compatibility with both tests and production
     */
    function diamondCutCallback(
        address _diamond, 
        IDiamondCut.FacetCut[] memory _cuts, 
        address _init, 
        bytes memory _calldata
    ) external override {
        // Direct call to the diamond
        (bool success, bytes memory returnData) = _diamond.call(
            abi.encodeWithSelector(
                IDiamondCut.diamondCut.selector,
                _cuts,
                _init,
                _calldata
            )
        );
        
        // Handle errors properly
        if (!success) {
            assembly {
                revert(add(32, returnData), mload(returnData))
            }
        }
    }

    function deployDiamond(address admin, address treasury) public returns (Deployment memory) {
        // Store admin for diamondCutCallback
        _admin = admin;
        
        // Deploy facets
        {{ deploy_facets }}

        // Deploy DiamondInit
        DiamondInit diamondInit = new DiamondInit();

        // Create FacetCut array for diamond constructor
        {{ facet_cuts }}

        // Initialize the diamond - only construct, don't make the diamond cut
        {{ diamond_creation }}

        // Return deployment info without calling diamondCut
        {{ deployment_return }}

        return Deployment({
            diamond: address(diamond),
            facets: facets,
            facetNames: facetNames
        });
    }

    function deployDiamondViaCreate2(bytes32 salt) public returns (address) {
        return address(0);
    }

    function predictDiamondAddress(bytes32 salt) public view returns (address) {
        return address(0);
    }

    function deployDeterministic(
        address admin,
        Salts memory salts,
        string memory prefix,
        ICreateX createX
    ) public returns (DeploymentAddresses memory) {
        return DeploymentAddresses({
            diamond: address(0),
            {{ deterministic_return_fields }}
        });
    }

    function predictDeterministicAddresses(
        Salts memory salts,
        string memory prefix,
        address deployer,
        ICreateX createX
    ) public view returns (DeploymentAddresses memory) {
        return DeploymentAddresses({
            diamond: address(0),
            {{ deterministic_addresses_return_fields }}
        });
    }
} 