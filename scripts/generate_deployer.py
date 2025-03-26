#!/usr/bin/env python3
import json
import os
import sys
import glob
import re
from typing import Dict, List, Tuple

class FacetManager:
    """Manages facet configurations loaded from facets.json"""
    
    def __init__(self, project_root):
        self.project_root = project_root
        self.facets = {}
        
        # Try to load from facets.json
        json_path = os.path.join(project_root, "scripts", "facets.json")
        try:
            with open(json_path, 'r') as f:
                self.facets = json.load(f)
                print(f"Loaded facet configuration from {json_path}")
        except (FileNotFoundError, json.JSONDecodeError) as e:
            print(f"Error: Failed to load facet configuration: {e}")
            sys.exit(1)
    
    def get_facet_names(self):
        return list(self.facets.keys())
    
    def is_required(self, facet_name):
        return self.facets.get(facet_name, {}).get("required", False)
    
    def is_payable(self, facet_name):
        return self.facets.get(facet_name, {}).get("payable", False)
    
    def is_initializable(self, facet_name):
        return self.facets.get(facet_name, {}).get("initializable", False)
    
    def get_owned_selectors(self, facet_name):
        return self.facets.get(facet_name, {}).get("ownedSelectors", [])
    
    def get_facet_field_name(self, facet_name):
        """Convert facet name to field name with correct naming convention"""
        # Convert CamelCase to snake_case
        s1 = re.sub('(.)([A-Z][a-z]+)', r'\1_\2', facet_name)
        return re.sub('([a-z0-9])([A-Z])', r'\1_\2', s1).lower().replace("_facet", "")
    
    def get_required_facets(self):
        """Get list of facets that are marked as required"""
        return [facet for facet, config in self.facets.items() if config.get("required", False)]

def find_artifact(facet_name, build_dir):
    """Find artifact file for a facet"""
    for pattern in [
        os.path.join(build_dir, f"**/{facet_name}.json"),
        os.path.join(build_dir, f"**/{facet_name}.sol/{facet_name}.json")
    ]:
        matches = glob.glob(pattern, recursive=True)
        if matches:
            return matches[0]
    return None

def get_all_owned_selectors(facet_manager):
    """Get a mapping of all owned selectors to their owning facets"""
    owned_map = {}  # selector -> facet_name
    for facet in facet_manager.get_facet_names():
        for selector in facet_manager.get_owned_selectors(facet):
            owned_map[selector] = facet
    return owned_map

def get_facet_selectors(facet_name, facet_manager, build_dir):
    """Extract selectors from facet artifact, excluding those owned by other facets"""
    artifact_path = find_artifact(facet_name, build_dir)
    if not artifact_path:
        return []
    
    try:
        with open(artifact_path) as f:
            artifact = json.load(f)
        
        # Get mapping of all owned selectors
        owned_selectors_map = get_all_owned_selectors(facet_manager)
        
        # Get all selectors except constructor
        available_selectors = []
        for method, sel in artifact.get("methodIdentifiers", {}).items():
            if not method.startswith("constructor"):
                # Check if this selector is owned by another facet
                owner = owned_selectors_map.get(method)
                if owner is None or owner == facet_name:
                    available_selectors.append((f"0x{sel}", method))
                else:
                    print(f"Skipping {facet_name}.{method} (owned by {owner})")
        
        return available_selectors
        
    except Exception as e:
        print(f"Error processing {facet_name}: {e}", file=sys.stderr)
        return []

def discover_facets(build_dir, facet_manager):
    """Discover facets from artifacts directory and configuration"""
    # Start with facets from configuration
    all_facets = set(facet_manager.get_facet_names())
    
    # Find all facet artifacts
    valid_facets = []
    for facet in all_facets:
        if find_artifact(facet, build_dir) or facet_manager.is_required(facet):
            valid_facets.append(facet)
    
    return valid_facets

def facet_name_to_var(facet_name):
    """Convert facet name to variable name (camelCase)"""
    # Simple underscore + base name
    return "_" + facet_name

def generate_template_parts(facets, facet_manager, build_dir):
    """Generate all template parts needed for substitution"""
    parts = {}
    
    # Generate imports
    imports = [f'import {{{facet}}} from "@facets/{facet}.sol";' for facet in facets]
    parts["facet_imports"] = "\n".join(imports)
    
    # Generate initializations
    init_lines = []
    selector_lines = []
    call_lines = []
    
    # First, generate all selector declarations
    for facet in facets:
        if facet_manager.is_initializable(facet):
            # Use selector and call with try/catch instead of direct method calls
            init_name = f"initialize{facet.replace('Facet', '')}"
            init_selector = f"bytes4 init{facet.replace('Facet', '')}Selector = {facet}.{init_name}.selector;"
            selector_lines.append(init_selector)
    
    # Then generate all the call statements with uniquely numbered success variables
    counter = 1
    for facet in facets:
        if facet_manager.is_initializable(facet):
            init_name = facet.replace('Facet', '')
            call_line = f"(bool success{counter},) = address(this).call(abi.encodePacked(init{init_name}Selector));"
            call_lines.append(call_line)
            call_lines.append(f"if (!success{counter}) {{}} // ignore error")
            counter += 1
    
    # Combine all lines
    init_lines = selector_lines + call_lines
    parts["facet_initializations"] = "\n        ".join(init_lines)
    
    # Generate struct fields
    parts["deployment_addresses_fields"] = "\n        ".join([f'address {facet_manager.get_facet_field_name(facet)};' for facet in facets])
    parts["salts_fields"] = "\n        ".join([f'bytes32 {facet_manager.get_facet_field_name(facet)};' for facet in facets])
    
    # Generate selector functions
    selector_functions = []
    for facet in facets:
        selectors = get_facet_selectors(facet, facet_manager, build_dir)
        function_lines = [
            f'function get{facet}Selectors() public pure returns (bytes4[] memory) {{',
            f'    bytes4[] memory selectors = new bytes4[]({len(selectors)});'
        ]
        
        for i, (selector, method) in enumerate(selectors):
            function_lines.append(f'    selectors[{i}] = {selector}; // {method}')
        
        function_lines.extend(['    return selectors;', '}'])
        selector_functions.append("\n    ".join(function_lines))
    parts["selector_functions"] = "\n    ".join(selector_functions)
    
    # Generate facet deployments
    deploy_lines = []
    for facet in facets:
        var_name = facet_name_to_var(facet)
        deploy_lines.append(f'{facet} {var_name} = new {facet}();')
    parts["deploy_facets"] = "\n        ".join(deploy_lines)
    
    # Generate facet cuts array (excluding DiamondCutFacet)
    cut_facets = [f for f in facets if f != "DiamondCutFacet"]
    cuts_code = [f'IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[]({len(cut_facets)});']
    
    for i, facet in enumerate(cut_facets):
        var_name = facet_name_to_var(facet)
        cuts_code.append(f'''
        cuts[{i}] = IDiamondCut.FacetCut({{
            facetAddress: address({var_name}),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: get{facet}Selectors()
        }});''')
    parts["facet_cuts"] = "".join(cuts_code)
    
    # Generate diamond creation
    diamond_cut_var = facet_name_to_var("DiamondCutFacet") if "DiamondCutFacet" in facets else "0"
    parts["diamond_creation"] = f'BTRDiamond diamond = new BTRDiamond(admin, treasury, address({diamond_cut_var}));'
    
    # Generate deployment returns
    facet_list = []
    facet_names = []
    for i, facet in enumerate(facets):
        var_name = facet_name_to_var(facet)
        facet_list.append(f'facets[{i}] = address({var_name});')
        facet_names.append(f'facetNames[{i}] = "{facet}";')
    
    parts["deployment_return"] = f'address[] memory facets = new address[]({len(facets)});\n        ' + \
                                '\n        '.join(facet_list) + \
                                f'\n        \n        string[] memory facetNames = new string[]({len(facets)});\n        ' + \
                                '\n        '.join(facet_names)
    
    # Generate deterministic return fields
    deterministic_fields = []
    for i, facet in enumerate(facets):
        field_name = facet_manager.get_facet_field_name(facet)
        field = f'{field_name}: address(0)'
        if i < len(facets) - 1:
            field += ','
        deterministic_fields.append(field)
    
    parts["deterministic_return_fields"] = "\n            ".join(deterministic_fields)
    parts["deterministic_addresses_return_fields"] = "\n            ".join(deterministic_fields)
    
    return parts

def generate_deployer(project_root, build_dir, facet_manager):
    # Find template
    template_path = os.path.join(project_root, "scripts", "templates", "DiamondDeployer.sol.tpl")
    if not os.path.exists(template_path):
        print(f"Error: Template file not found at {template_path}")
        sys.exit(1)
    
    with open(template_path, 'r') as f:
        template = f.read()
    
    # Discover facets
    facets = discover_facets(build_dir, facet_manager)
    if not facets:
        print("Error: No facets found!")
        sys.exit(1)
    
    # Generate all template parts
    parts = generate_template_parts(facets, facet_manager, build_dir)
    
    # Replace placeholders in template
    for key, value in parts.items():
        template = template.replace(f'{{{{ {key} }}}}', value)
    
    # Write the generated deployer
    output_path = os.path.join(build_dir, '..', 'utils', 'generated')
    os.makedirs(output_path, exist_ok=True)
    
    with open(os.path.join(output_path, 'DiamondDeployer.gen.sol'), 'w') as f:
        f.write(template)
    
    print(f"Generated DiamondDeployer.gen.sol at {output_path}")

def main():
    if len(sys.argv) < 2:
        print("Usage: python generate_deployer.py <build_directory>")
        sys.exit(1)
    
    build_dir = sys.argv[1]
    project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    
    facet_manager = FacetManager(project_root)
    generate_deployer(project_root, build_dir, facet_manager)

if __name__ == "__main__":
    main() 
