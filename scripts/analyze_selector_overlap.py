#!/usr/bin/env python3

import os
import re
import glob
import hashlib

def function_to_selector(function_signature):
    """Convert a function signature to its selector."""
    # Remove any whitespace and new lines
    function_signature = re.sub(r'\s+', ' ', function_signature).strip()
    
    # Hash using keccak256
    encoded = function_signature.encode('utf-8')
    hashed = hashlib.sha3_256(encoded).hexdigest()
    
    # Return first 4 bytes (8 hex characters)
    return "0x" + hashed[:8]

def extract_functions_from_file(file_path):
    """Extract function signatures from a Solidity file."""
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Find all public/external function declarations
    # This is a simplified regex and might not catch all edge cases
    functions = re.findall(r'function\s+([a-zA-Z0-9_]+)\s*\(([^)]*)\)[^{;]*(?:external|public)[^{;]*', content)
    
    result = []
    for name, params in functions:
        # Clean up parameters
        params = re.sub(r'\s+', ' ', params).strip()
        params = re.sub(r'\s*,\s*', ',', params)
        
        # Build signature and get selector
        signature = f"{name}({params})"
        selector = function_to_selector(signature)
        
        result.append((signature, selector))
    
    return result

def analyze_facets():
    """Analyze all facets for function selector overlaps."""
    facet_path = os.path.join('evm', 'src', 'facets', '*.sol')
    facet_files = glob.glob(facet_path)
    
    # Dictionary to track which facets define each selector
    selectors = {}
    
    for file_path in facet_files:
        facet_name = os.path.basename(file_path)
        functions = extract_functions_from_file(file_path)
        
        for signature, selector in functions:
            if selector not in selectors:
                selectors[selector] = []
            selectors[selector].append((facet_name, signature))
    
    # Find overlaps
    overlaps = {s: facets for s, facets in selectors.items() if len(facets) > 1}
    
    if overlaps:
        print("Found function selector overlaps:")
        for selector, facets in overlaps.items():
            print(f"\nSelector: {selector}")
            for facet_name, signature in facets:
                print(f"  {facet_name}: {signature}")
    else:
        print("No function selector overlaps found.")

if __name__ == "__main__":
    analyze_facets() 