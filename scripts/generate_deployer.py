#!/usr/bin/env python3
import os
import sys
import glob
from extract_selectors import extract_selectors, generate_selector_function

def generate_facet_imports(facets):
    """Generate import statements for facets"""
    imports = []
    for facet in facets:
        imports.append(f'import {{{facet}}} from "@facets/{facet}.sol";')
    return '\n'.join(imports)

def find_artifacts_dir(base_dir):
    """Find the artifacts directory containing compiled contracts"""
    potential_paths = [
        os.path.join(base_dir, "out"),
        os.path.join(base_dir, "artifacts")
    ]
    
    for path in potential_paths:
        if os.path.exists(path):
            return path
    
    return None

def find_artifact_file(facet_name, artifacts_dir):
    """Find the artifact file for a facet"""
    potential_paths = [
        os.path.join(artifacts_dir, f"{facet_name}.sol", f"{facet_name}.json"),
        os.path.join(artifacts_dir, "src", "facets", f"{facet_name}.sol", f"{facet_name}.json"),
        os.path.join(artifacts_dir, "temp_src", "facets", f"{facet_name}.sol", f"{facet_name}.json")
    ]
    
    # Also try to find it with a glob pattern
    glob_patterns = [
        os.path.join(artifacts_dir, "**", f"{facet_name}.json"),
        os.path.join(artifacts_dir, "**", f"{facet_name}.sol", f"{facet_name}.json")
    ]
    
    for path in potential_paths:
        if os.path.exists(path):
            return path
    
    # Try glob patterns if direct paths don't work
    for pattern in glob_patterns:
        matches = glob.glob(pattern, recursive=True)
        if matches:
            return matches[0]
    
    return None

def generate_all_selector_functions(facets, evm_dir):
    """Generate all selector functions for the given facets"""
    all_functions = []
    artifacts_dir = find_artifacts_dir(evm_dir)
    
    if not artifacts_dir:
        print(f"Error: Could not find artifacts directory in {evm_dir}", file=sys.stderr)
        sys.exit(1)
    
    for facet in facets:
        artifact_file = find_artifact_file(facet, artifacts_dir)
        
        if artifact_file:
            print(f"Found artifact for {facet} at {artifact_file}")
            selectors = extract_selectors(facet, os.path.dirname(os.path.dirname(artifact_file)))
            if selectors:
                function_code = generate_selector_function(facet, selectors)
                all_functions.append(function_code)
                continue
        
        print(f"Warning: No selectors found for {facet}", file=sys.stderr)
        # Generate empty selector function
        empty_function = f"""
    // Function selectors for {facet}
    function get{facet}Selectors() internal pure returns (bytes4[] memory) {{
        bytes4[] memory selectors = new bytes4[](0);
        return selectors;
    }}"""
        all_functions.append(empty_function)
    
    return "\n".join(all_functions)

def generate_facet_deployment(facets):
    """Generate code for facet deployment"""
    lines = []
    lines.append(f"        // Initialize arrays")
    lines.append(f"        address[] memory facets = new address[]({len(facets)});")
    lines.append(f"        string[] memory facetNames = new string[]({len(facets)});")
    lines.append("")
    lines.append(f"        // Deploy facets")
    
    for i, facet in enumerate(facets):
        var_name = facet[0].lower() + facet[1:]
        lines.append(f"        {facet} {var_name} = new {facet}();")
        lines.append(f"        facets[{i}] = address({var_name});")
        lines.append(f'        facetNames[{i}] = "{facet}";')
        lines.append("")
    
    lines.append("        // Deploy initializer")
    lines.append("        DiamondInit diamondInit = new DiamondInit();")
    
    return '\n'.join(lines)

def generate_diamond_init(facets):
    """Generate code for diamond initialization"""
    lines = []
    lines.append(f"        // Prepare facet cuts")
    lines.append(f"        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[]({len(facets)});")
    lines.append("")
    
    for i, facet in enumerate(facets):
        lines.append(f"        cuts[{i}] = IDiamondCut.FacetCut({{")
        lines.append(f"            facetAddress: facets[{i}],")
        lines.append(f"            action: IDiamondCut.FacetCutAction.Add,")
        lines.append(f"            functionSelectors: get{facet}Selectors()")
        lines.append(f"        }});")
        lines.append("")
    
    lines.append(f"        // Execute diamond cut and initialize")
    lines.append(f"        bytes memory calldata_ = abi.encodeWithSelector(DiamondInit.init.selector, admin);")
    lines.append(f"        IDiamondCut(diamond).diamondCut(cuts, diamondInit, calldata_);")
    
    return '\n'.join(lines)

def process_template(template_path, output_path, facets, evm_dir):
    """Process the template file and generate the output file"""
    try:
        with open(template_path, 'r') as f:
            template = f.read()
    except Exception as e:
        print(f"Error: Failed to read template file {template_path}: {e}", file=sys.stderr)
        sys.exit(1)
    
    # Replace placeholders
    template = template.replace('// FACET_IMPORTS_PLACEHOLDER', generate_facet_imports(facets))
    template = template.replace('// SELECTOR_FUNCTIONS_PLACEHOLDER', generate_all_selector_functions(facets, evm_dir))
    template = template.replace('// DEPLOY_FACETS_PLACEHOLDER', generate_facet_deployment(facets))
    template = template.replace('// INITIALIZE_DIAMOND_PLACEHOLDER', generate_diamond_init(facets))
    
    # Write the output file
    try:
        os.makedirs(os.path.dirname(output_path), exist_ok=True)
        with open(output_path, 'w') as f:
            f.write(template)
    except Exception as e:
        print(f"Error: Failed to write output file {output_path}: {e}", file=sys.stderr)
        sys.exit(1)
    
    print(f"Diamond deployer generated at {output_path}")

def generate_deployer(facets):
    """Generate the deployer file - without building"""
    print("Generating diamond deployer...")
    
    # Navigate to the evm directory
    evm_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "evm")
    if not os.path.exists(evm_dir):
        print(f"Error: evm directory not found at {evm_dir}", file=sys.stderr)
        sys.exit(1)
    
    current_dir = os.getcwd()
    os.chdir(evm_dir)
    
    # Define file paths
    template_path = os.path.join(os.path.dirname(evm_dir), "scripts", "templates", "DiamondDeployer.sol.tpl")
    output_path = os.path.join(evm_dir, "utils", "DiamondDeployer.sol")
    
    # Ensure the output directory exists
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    
    # Remove existing deployer file
    if os.path.exists(output_path):
        os.remove(output_path)
    
    # Process the template
    process_template(template_path, output_path, facets, evm_dir)
    
    # Return to the original directory
    os.chdir(current_dir)

def main():
    # List of facets to process (excluding abstract facets and interfaces)
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
    
    # Generate the deployer (no build)
    generate_deployer(facets)

if __name__ == "__main__":
    main() 