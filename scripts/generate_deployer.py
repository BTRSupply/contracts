#!/usr/bin/env python3
import json
import os
import sys
import glob

# Define selector groups once at module level to avoid redundancy
ACCESS_CONTROL_SELECTORS = [
    "admin()",
    "treasury()",
    "getKeepers()",
    "getManagers()",
    "isAdmin(address)",
    "isTreasury(address)",
    "isKeeper(address)",
    "isManager(address)",
    "isBlacklisted(address)",
    "isWhitelisted(address)",
    "checkRole(bytes32)",
    "checkRole(bytes32,address)",
    "hasRole(bytes32,address)",
    "grantRole(bytes32,address)",
    "revokeRole(bytes32,address)",
    "renounceRole(bytes32,address)"
]

PAUSE_SELECTORS = [
    "isPaused()",
    "isPaused(uint32)",
    "pause()",
    "pause(uint32)",
    "unpause()",
    "unpause(uint32)",
    "paused()"
]

TREASURY_SELECTORS = [
    "getTreasury()",
    "setTreasury(address)"
]

LOUPE_SELECTORS = [
    "supportsInterface(bytes4)"
]

def find_artifact_file(facet_name, artifacts_dir):
    """Find the artifact file for a facet"""
    # Check direct paths first (faster)
    for path in [
        os.path.join(artifacts_dir, f"{facet_name}.sol", f"{facet_name}.json"),
        os.path.join(artifacts_dir, "src", "facets", f"{facet_name}.sol", f"{facet_name}.json"),
        os.path.join(artifacts_dir, "temp_src", "facets", f"{facet_name}.sol", f"{facet_name}.json")
    ]:
        if os.path.exists(path):
            return path
    
    # Try glob patterns if direct paths don't work
    for pattern in [
        os.path.join(artifacts_dir, "**", f"{facet_name}.json"),
        os.path.join(artifacts_dir, "**", f"{facet_name}.sol", f"{facet_name}.json")
    ]:
        matches = glob.glob(pattern, recursive=True)
        if matches:
            return matches[0]
    
    return None

def get_excluded_selectors():
    """Get selectors that should be excluded from certain facets"""
    # Each facet has its own excluded selectors
    return {
        "AccessControlFacet": [],  # No exclusions for AccessControlFacet
        "ManagementFacet": [], # No exclusions for ManagementFacet
        "ALL_OTHERS": ACCESS_CONTROL_SELECTORS + PAUSE_SELECTORS  # All other facets exclude these selectors
    }

def get_permissioned_facet_selectors():
    """Get selectors that should only be included in specific facets"""
    return {
        "AccessControlFacet": ACCESS_CONTROL_SELECTORS,
        "ManagementFacet": PAUSE_SELECTORS,
        "DiamondLoupeFacet": LOUPE_SELECTORS,
        "TreasuryFacet": TREASURY_SELECTORS
    }

def should_include_selector(facet_name, selector_name):
    """Determine if a selector should be included in a facet"""
    excluded_selectors = get_excluded_selectors()
    permissioned_selectors = get_permissioned_facet_selectors()
    
    # Check if this is a permissioned selector that should only be in specific facets
    for facet, selectors in permissioned_selectors.items():
        if selector_name in selectors:
            # If this selector is permissioned to a specific facet,
            # only include it in that facet
            return facet_name == facet
    
    # Check if this selector is excluded for this facet
    if facet_name in excluded_selectors and selector_name in excluded_selectors[facet_name]:
        return False
    
    # Check if this selector is excluded for all other facets except specific ones
    if facet_name not in ["AccessControlFacet", "ManagementFacet"] and selector_name in excluded_selectors["ALL_OTHERS"]:
        return False
    
    return True

def extract_selectors(facet_name, artifacts_dir):
    """Extract function selectors from a compiled facet artifact"""
    artifact_path = find_artifact_file(facet_name, artifacts_dir)
    
    if not artifact_path:
        print(f"Warning: Artifact not found for {facet_name} in {artifacts_dir}", file=sys.stderr)
        return None
    
    try:
        with open(artifact_path, 'r') as f:
            artifact = json.load(f)
        
        if "methodIdentifiers" not in artifact:
            print(f"Warning: No method identifiers found in {facet_name} artifact", file=sys.stderr)
            return None
        
        # Filter out constructors and include only appropriate selectors
        selectors = [(f"0x{selector}", method) for method, selector in artifact["methodIdentifiers"].items() 
                if not method.startswith("constructor") and should_include_selector(facet_name, method)]
        
        # Sort by method name
        selectors.sort(key=lambda x: x[1])
        
        return selectors
    except Exception as e:
        print(f"Error processing {facet_name} artifact: {e}", file=sys.stderr)
        return None

def get_initialize_method(facet_name):
    """Get the initialize method for a facet"""
    base_name = facet_name.replace("Facet", "")
    # Special case for treasury facet which takes an address parameter
    if facet_name == "TreasuryFacet":
        return f"initialize{base_name}(address)"
    return f"initialize{base_name}()"

def get_facet_selectors(facet_name, artifacts_dir):
    """Get selectors for a facet"""
    selectors = extract_selectors(facet_name, artifacts_dir)
    if selectors is None:
        print(f"No selectors found for {facet_name}", file=sys.stderr)
        return None
    
    # Sort selectors by name for consistency
    selectors.sort(key=lambda x: x[1])
    
    return selectors

def generate_selector_function(facet_name, selectors):
    """Generate a function to return selectors for a facet"""
    lines = []
    
    # Add function comment
    lines.append(f"    // Function selectors for {facet_name}")
    
    # Add function definition
    lines.append(f"    function get{facet_name}Selectors() public pure returns (bytes4[] memory) {{")
    
    # Add selector array
    lines.append(f"        bytes4[] memory selectors = new bytes4[]({len(selectors)});")
    
    # Add each selector
    for i, (selector_hex, signature) in enumerate(selectors):
        lines.append(f"        selectors[{i}] = bytes4({selector_hex}); /* {signature} */")
    
    # Close function
    lines.append("        return selectors;")
    lines.append("    }")
    lines.append("")
    
    return lines

def find_artifacts_dir(base_dir):
    """Find the artifacts directory in the project"""
    # Try common paths
    for path in ["out", os.path.join(base_dir, "out")]:
        if os.path.exists(path) and os.path.isdir(path):
            return path
    return None

def generate_diamond_init_function(facets):
    """Generate the init function for DiamondInit"""
    lines = []
    lines.append("    function init(address admin, address treasury) external {")
    lines.append("        // Each of these calls will delegate through the diamond to the respective facet")
    lines.append("        ")
    lines.append("        // We skip AccessControl initialization because it's already done in the BTRDiamond constructor")
    lines.append("        // That's why our previous initialization was failing")
    lines.append("        // Note: Admin should already have all required roles (ADMIN_ROLE, MANAGER_ROLE, etc.)")
    lines.append("        ")
    lines.append("        bool success;")
    lines.append("        ")
    
    # For each facet (except DiamondCutFacet, DiamondLoupeFacet, and AccessControl)
    # Add initialization calls
    for facet in facets:
        if facet not in ["DiamondCutFacet", "DiamondLoupeFacet", "AccessControlFacet"]:
            base_name = facet.replace("Facet", "")
            init_method = get_initialize_method(facet)
            
            lines.append(f"        // Initialize {facet}")
            lines.append(f'        bytes4 init{base_name} = bytes4(keccak256("{init_method}"));')
            
            # Special case for TreasuryFacet since it takes a parameter
            if facet == "TreasuryFacet":
                lines.append(f"        (success,) = address(this).delegatecall(")
                lines.append(f"            abi.encodeWithSelector(init{base_name}, treasury)")
                lines.append("        );")
            else:
                lines.append(f"        (success,) = address(this).delegatecall(")
                lines.append(f"            abi.encodeWithSelector(init{base_name})")
                lines.append("        );")
                
            lines.append(f'        require(success, "{base_name} initialization failed");')
            lines.append("        ")
    
    lines.append("    }")
    
    return lines

def generate_facet_imports(facets):
    """Generate import statements for each facet"""
    lines = []
    for facet in facets:
        lines.append(f'import {{{facet}}} from "@facets/{facet}.sol";')
    return lines

def generate_deployer(artifacts_dir=None):
    """Generate the diamond deployer file"""
    if not artifacts_dir:
        artifacts_dir = find_artifacts_dir("evm")
    
    if not artifacts_dir:
        print("Error: Could not find artifacts directory", file=sys.stderr)
        return False

    print("Generating diamond deployer...")
    
    # List of facets to include
    facets = [
        "DiamondCutFacet",
        "DiamondLoupeFacet",
        "AccessControlFacet",
        "ManagementFacet",
        "RescueFacet",
        "SwapperFacet",
        "ALMFacet",
        "TreasuryFacet"
    ]
    
    # Get selectors for each facet
    facet_selectors = {}
    for facet in facets:
        selectors = get_facet_selectors(facet, artifacts_dir)
        if selectors is None:
            print(f"Error: Could not get selectors for {facet}", file=sys.stderr)
            return False
        facet_selectors[facet] = selectors
    
    # Load the template file
    template_file = os.path.join("scripts", "templates", "DiamondDeployer.sol.tpl")
    if not os.path.exists(template_file):
        print(f"Error: Template file not found at {template_file}", file=sys.stderr)
        return False
    
    try:
        with open(template_file, 'r') as f:
            template = f.read()
    except Exception as e:
        print(f"Error reading template file: {e}", file=sys.stderr)
        return False
    
    # Generate facet imports
    facet_imports = generate_facet_imports(facets)
    template = template.replace("// FACET_IMPORTS_PLACEHOLDER", "\n".join(facet_imports))
    
    # Generate selector functions
    selector_functions = []
    for facet in facets:
        selector_functions.extend(generate_selector_function(facet, facet_selectors[facet]))
    template = template.replace("// SELECTOR_FUNCTIONS_PLACEHOLDER", "\n".join(selector_functions))
    
    # Replace DiamondInit function (only if the placeholder exists)
    if "// DIAMOND_INIT_FUNCTION_PLACEHOLDER" in template:
        diamond_init_function = generate_diamond_init_function(facets)
        template = template.replace("    // DIAMOND_INIT_FUNCTION_PLACEHOLDER", "\n".join(diamond_init_function))
    
    # Write the file
    try:
        output_dir = os.path.join("evm", "utils", "generated")
        os.makedirs(output_dir, exist_ok=True)
        output_path = os.path.join(output_dir, "DiamondDeployer.gen.sol")
        with open(output_path, "w") as f:
            f.write(template)
        print(f"Diamond deployer generated at {output_path}")
        return True
    except Exception as e:
        print(f"Error writing deployer file: {e}", file=sys.stderr)
        return False

def main():
    if len(sys.argv) > 1:
        if sys.argv[1] == "extract":
            # Extract selectors mode
            artifacts_dir = sys.argv[2] if len(sys.argv) > 2 else "out"
            facets = sys.argv[3:] if len(sys.argv) > 3 else []
            
            if not facets:
                print("Usage: generate_deployer.py extract <artifacts_dir> <facet1> [facet2] ...", file=sys.stderr)
                sys.exit(1)
            
            for facet in facets:
                selectors = extract_selectors(facet, artifacts_dir)
                print(generate_selector_function(facet, selectors))
        elif sys.argv[1] == "facets":
            # Custom facets list mode
            facets = sys.argv[2:] if len(sys.argv) > 2 else []
            if not facets:
                print("Usage: generate_deployer.py facets <facet1> [facet2] ...", file=sys.stderr)
                sys.exit(1)
            
            artifacts_dir = find_artifacts_dir("evm")
            if not artifacts_dir:
                print("Error: Could not find artifacts directory", file=sys.stderr)
                sys.exit(1)
            
            for facet in facets:
                selectors = get_facet_selectors(facet, artifacts_dir)
                if selectors is None:
                    print(f"Error: Could not get selectors for {facet}", file=sys.stderr)
                    sys.exit(1)
        else:
            # Use custom artifacts directory
            artifacts_dir = sys.argv[1]
            generate_deployer(artifacts_dir)
    else:
        generate_deployer()

if __name__ == "__main__":
    main() 