use ethers::prelude::*;
use regex::Regex;

#[derive(Clone)]
pub enum PatternType {
    // Plain prefix matching
    Prefix(Vec<u8>),
    // Regex pattern matching
    Regex(Regex),
    // Advanced pattern with leading, middle, and trailing parts
    Advanced {
        leading: Option<Vec<Vec<u8>>>,  // Leading options
        trailing: Option<Vec<Vec<u8>>>, // Trailing options
    }
}

pub fn parse_pattern(pattern_str: &str) -> PatternType {
    // Check for advanced pattern with "..."
    if pattern_str.contains("...") {
        let parts: Vec<&str> = pattern_str.split("...").collect();
        
        return PatternType::Advanced {
            leading: (!parts[0].is_empty()).then(|| parse_or_conditions(parts[0])),
            trailing: (parts.len() > 1 && !parts[1].is_empty()).then(|| parse_or_conditions(parts[1])),
        };
    }
    
    // Try as regex pattern if it has OR conditions
    if pattern_str.contains('|') && (pattern_str.contains('(') || pattern_str.contains(')')) {
        return match Regex::new(&format!("^{}$", hex_or_pattern_to_regex(pattern_str))) {
            Ok(regex) => PatternType::Regex(regex),
            Err(_) => {
                println!("Warning: Invalid regex pattern, falling back to prefix match");
                decode_hex_or_default(pattern_str)
            }
        };
    }
    
    // Default to prefix matching
    decode_hex_or_default(pattern_str)
}

fn decode_hex_or_default(hex_str: &str) -> PatternType {
    match hex::decode(hex_str) {
        Ok(bytes) => PatternType::Prefix(bytes),
        Err(_) => {
            println!("Warning: Invalid hex pattern, assuming empty pattern");
            PatternType::Prefix(vec![])
        }
    }
}

pub fn parse_or_conditions(pattern: &str) -> Vec<Vec<u8>> {
    // Handle grouped options (A|B|C)
    if pattern.starts_with('(') && pattern.ends_with(')') && pattern.contains('|') {
        let options_str = &pattern[1..pattern.len()-1];
        return options_str.split('|')
            .filter_map(|opt| hex::decode(opt).ok())
            .collect();
    }
    
    // Single option case
    match hex::decode(pattern) {
        Ok(bytes) => vec![bytes],
        Err(_) => {
            println!("Warning: Invalid hex in pattern: {}", pattern);
            vec![]
        }
    }
}

pub fn hex_or_pattern_to_regex(pattern: &str) -> String {
    // Simple pass-through for now - the complex implementation didn't add much value
    pattern.to_string()
}

pub fn address_matches_pattern(address: &Address, pattern: &PatternType) -> bool {
    let address_hex = format!("{:x}", address);
    let address_bytes = address.as_bytes();
    
    match pattern {
        PatternType::Prefix(prefix) => {
            prefix.len() <= address_bytes.len() && address_bytes.starts_with(prefix)
        },
        PatternType::Regex(regex) => regex.is_match(&address_hex),
        PatternType::Advanced { leading, trailing } => {
            // Check leading pattern
            if let Some(options) = leading {
                if !options.iter().any(|opt| address_bytes.starts_with(opt)) {
                    return false;
                }
            }
            
            // Check trailing pattern
            if let Some(options) = trailing {
                if !options.iter().any(|opt| {
                    opt.len() <= address_bytes.len() && 
                    address_bytes[address_bytes.len() - opt.len()..].eq(opt)
                }) {
                    return false;
                }
            }
            
            true
        }
    }
}

pub fn describe_pattern(pattern: &PatternType) -> String {
    match pattern {
        PatternType::Prefix(prefix) => format!("addresses starting with: 0x{}", hex::encode(prefix)),
        PatternType::Regex(regex) => format!("addresses matching regex: {}", regex),
        PatternType::Advanced { leading, trailing } => {
            let mut parts = Vec::new();
            
            if let Some(lead) = leading {
                let options = lead.iter()
                    .map(|bytes| format!("0x{}", hex::encode(bytes)))
                    .collect::<Vec<_>>()
                    .join(" or ");
                parts.push(format!("leading: {}", options));
            }
            
            if let Some(trail) = trailing {
                let options = trail.iter()
                    .map(|bytes| format!("0x{}", hex::encode(bytes)))
                    .collect::<Vec<_>>()
                    .join(" or ");
                parts.push(format!("trailing: {}", options));
            }
            
            format!("addresses with {}", parts.join(" and "))
        }
    }
}

// Get pattern info for GPU implementation
pub fn get_pattern_for_gpu(pattern: &PatternType) -> (Vec<u8>, usize) {
    match pattern {
        PatternType::Prefix(prefix) => (prefix.clone(), prefix.len()),
        // For GPU, we only support prefix matching efficiently
        _ => (vec![], 0),
    }
}
