#!/usr/bin/env python3
import json
import sys
import os
import glob
from pathlib import Path

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

def extract_selectors(facet_name, artifacts_dir="out"):
    """Extract function selectors from a compiled facet artifact"""
    artifact_path = find_artifact_file(facet_name, artifacts_dir)
    
    if not artifact_path:
        print(f"Warning: Artifact not found for {facet_name} in {artifacts_dir}", file=sys.stderr)
        return []
    
    try:
        with open(artifact_path, 'r') as f:
            artifact = json.load(f)
        
        if "methodIdentifiers" not in artifact:
            print(f"Warning: No method identifiers found in {facet_name} artifact", file=sys.stderr)
            return []
        
        # Extract method identifiers
        selectors = []
        for method, selector in artifact["methodIdentifiers"].items():
            # Skip constructor
            if method.startswith("constructor"):
                continue
                
            selectors.append((selector, method))
        
        return selectors
    except Exception as e:
        print(f"Error processing {facet_name} artifact: {e}", file=sys.stderr)
        return []

def generate_selector_function(facet_name, selectors):
    """Generate the Solidity code for a selector function"""
    lines = []
    lines.append(f"")
    lines.append(f"    // Function selectors for {facet_name}")
    lines.append(f"    function get{facet_name}Selectors() internal pure returns (bytes4[] memory) {{")
    lines.append(f"        bytes4[] memory selectors = new bytes4[]({len(selectors)});")
    
    for i, (selector, method) in enumerate(selectors):
        lines.append(f"        selectors[{i}] = bytes4(0x{selector}); /* {method} */")
    
    lines.append("        return selectors;")
    lines.append("    }")
    
    return "\n".join(lines)

def main():
    if len(sys.argv) < 2:
        print("Usage: extract_selectors.py <facet_name> [artifacts_dir]", file=sys.stderr)
        sys.exit(1)
    
    facet_name = sys.argv[1]
    artifacts_dir = sys.argv[2] if len(sys.argv) > 2 else "out"
    
    selectors = extract_selectors(facet_name, artifacts_dir)
    if not selectors:
        print(f"No selectors found for {facet_name}")
        sys.exit(1)
        
    print(generate_selector_function(facet_name, selectors))

if __name__ == "__main__":
    main() 