#!/usr/bin/env python3
import json
import sys
import os
from extract_selectors import extract_selectors, generate_selector_function

def generate_all_selector_functions(facets, artifacts_dir="out"):
    """Generate all selector functions for the given facets"""
    all_functions = []
    
    for facet in facets:
        selectors = extract_selectors(facet, artifacts_dir)
        if selectors:
            function_code = generate_selector_function(facet, selectors)
            all_functions.append(function_code)
        else:
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

def main():
    if len(sys.argv) < 2:
        print("Usage: generate_all_selectors.py <artifacts_dir> <facet1> [facet2] ...", file=sys.stderr)
        sys.exit(1)
    
    artifacts_dir = sys.argv[1]
    facets = sys.argv[2:]
    
    if not facets:
        print("No facets specified", file=sys.stderr)
        sys.exit(1)
    
    all_functions = generate_all_selector_functions(facets, artifacts_dir)
    print(all_functions)

if __name__ == "__main__":
    main() 