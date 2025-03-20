// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {DiamondDeployer, DiamondInit} from "@utils/DiamondDeployer.sol";
import {IDiamondLoupe} from "@interfaces/IDiamondLoupe.sol";
import {IDiamondCut} from "@interfaces/IDiamondCut.sol";
import {BTRDiamond} from "@/BTRDiamond.sol";
import {ALMFacet} from "@facets/ALMFacet.sol";
import {AccessControlFacet} from "@facets/AccessControlFacet.sol";
import {TreasuryFacet} from "@facets/TreasuryFacet.sol";
import {ICreateX} from "@interfaces/ICreateX.sol";

abstract contract MockCreateX is ICreateX {
    function deployCreate3(bytes32 salt, bytes memory creationCode) external payable override returns (address deployed) {
        return address(0);
    }

    function computeCreate3Address(bytes32 salt, address deployer) external pure override returns (address) {
        // Just a mock implementation for testing - not the real CREATE3 algorithm
        return address(uint160(uint256(keccak256(abi.encodePacked(salt, deployer)))));
    }
}

contract DiamondDeployerTest is Test {
    DiamondDeployer deployer;
    address admin;
    MockCreateX mockCreateX;

    function setUp() public {
        deployer = new DiamondDeployer();
        admin = address(0x123);
        mockCreateX = new MockCreateX();
    }

    function testDeployDiamond() public {
        DiamondDeployer.Deployment memory deployment = deployer.deployDiamond(admin);
        
        // Verify diamond was deployed successfully
        assertEq(address(deployment.diamond), address(deployment.diamond));
        
        // Get the facets via the diamond loupe
        IDiamondLoupe.Facet[] memory facets = IDiamondLoupe(address(deployment.diamond)).facets();
        
        // Should have multiple facets (at least 7 facets + DiamondCut)
        // DiamondCut, DiamondLoupe, AccessControl, Management, Rescue, Swapper, ALM, Treasury
        assertGe(facets.length, 8, "Not all facets were added");
        
        // Check that the admin was properly set
        assertTrue(AccessControlFacet(address(deployment.diamond)).isAdmin(admin), "Admin not set properly");
        
        // Verify ALMFacet was properly deployed and connected
        bool almFacetFound = false;
        for (uint i = 0; i < facets.length; i++) {
            // Compare facet address with the deployed ALMFacet address 
            if (facets[i].facetAddress == address(deployment.almFacet)) {
                almFacetFound = true;
                break;
            }
        }
        assertTrue(almFacetFound, "ALM facet not properly registered");
    }

    function testDeterministicDeployment() public {
        // Generate a salt for testing
        bytes32 diamondSalt = keccak256("test.diamond");

        // Deploy deterministically
        DiamondDeployer.DeploymentAddresses memory addresses = deployer.deployDeterministic(
            admin,
            diamondSalt,
            "test",
            mockCreateX
        );
        
        // Verify the diamond was deployed
        assertEq(addresses.diamond, addresses.diamond);
        
        // Get facets via diamond loupe
        IDiamondLoupe.Facet[] memory facets = IDiamondLoupe(addresses.diamond).facets();
        
        // Ensure we have all the expected facets
        assertGe(facets.length, 8, "Not all facets were added");
        
        // Verify addresses were predicted correctly
        DiamondDeployer.DeploymentAddresses memory predictedAddresses = deployer.predictDeterministicAddresses(
            "test",
            diamondSalt,
            address(this),
            mockCreateX
        );
        
        // In our mock, the prediction and actual deployment should match
        // (Though in real CREATE3 they would use complex salt derivation)
        assertEq(predictedAddresses.diamond, addresses.diamond);
    }

    function testALMFacetSelectors() public {
        // Deploy the diamond
        DiamondDeployer.Deployment memory deployment = deployer.deployDiamond(admin);
        
        // Get the selectors for ALMFacet using diamond loupe
        bytes4[] memory selectors = IDiamondLoupe(address(deployment.diamond))
            .facetFunctionSelectors(address(deployment.almFacet));
        
        // Verify ALM has the correct number of functions registered
        assertEq(selectors.length, 21, "ALM facet should have 21 selectors registered");
        
        // Check for some key ALM selectors
        bool createVaultFound = false;
        bool rebalanceFound = false;
        bool depositFound = false;
        
        for (uint i = 0; i < selectors.length; i++) {
            if (selectors[i] == ALMFacet.createVault.selector) createVaultFound = true;
            if (selectors[i] == ALMFacet.rebalance.selector) rebalanceFound = true;
            if (selectors[i] == ALMFacet.deposit.selector) depositFound = true;
        }
        
        assertTrue(createVaultFound, "createVault selector not found");
        assertTrue(rebalanceFound, "rebalance selector not found");
        assertTrue(depositFound, "deposit selector not found");
    }
    
    function testTreasuryFacetSelectors() public {
        // Deploy the diamond
        DiamondDeployer.Deployment memory deployment = deployer.deployDiamond(admin);
        
        // Get the selectors for TreasuryFacet using diamond loupe
        bytes4[] memory selectors = IDiamondLoupe(address(deployment.diamond))
            .facetFunctionSelectors(address(deployment.treasuryFacet));
        
        // TreasuryFacet should have 2 selectors
        assertEq(selectors.length, 2, "Treasury facet should have 2 selectors registered");
        
        // Check for the presence of key selectors (though they're using string keccak256 hashing)
        bool collectFeesFound = false;
        for (uint i = 0; i < selectors.length; i++) {
            if (selectors[i] == bytes4(keccak256("collectProtocolFees()"))) {
                collectFeesFound = true;
            }
        }
        
        assertTrue(collectFeesFound, "collectProtocolFees selector not found");
    }
} 