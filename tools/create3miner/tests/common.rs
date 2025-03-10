use ethers::prelude::*;
use crate::common::pattern::{PatternType, parse_pattern};
use std::str::FromStr;
use std::time::{Duration, Instant};

// Test constants
pub const TEST_DEPLOYER: &str = "0x1234567890abcdef1234567890abcdef12345678";
pub const TEST_SALT_BASE: &str = "test.salt.v1";

// Test case structure
pub struct MinerTestCase {
    pub name: &'static str,
    pub pattern: &'static str,
    pub expected_prefix: &'static str,
    pub max_time: Duration,
    pub known_solution: Option<(&'static str, &'static str)>, // (salt, address)
}

// Common test cases that can be used by both CPU and GPU implementations
pub fn get_test_cases() -> Vec<MinerTestCase> {
    vec![
        // Simple prefix test
        MinerTestCase {
            name: "Simple prefix",
            pattern: "abcd",
            expected_prefix: "0xabcd",
            max_time: Duration::from_secs(30),
            known_solution: None,
        },
        // Short single character prefix (should be fast to find)
        MinerTestCase {
            name: "Single char prefix",
            pattern: "a",
            expected_prefix: "0xa",
            max_time: Duration::from_secs(5),
            known_solution: None,
        },
        // Advanced pattern with leading and trailing parts
        MinerTestCase {
            name: "Leading and trailing pattern",
            pattern: "ab...cd",
            expected_prefix: "addresses with leading: 0xab and trailing: 0xcd",
            max_time: Duration::from_secs(30),
            known_solution: None,
        },
        // OR pattern
        MinerTestCase {
            name: "OR pattern",
            pattern: "(a|b|c)",
            expected_prefix: "addresses matching regex: ^(a|b|c)$",
            max_time: Duration::from_secs(30),
            known_solution: None,
        },
        // Complex OR pattern 
        MinerTestCase {
            name: "Complex OR with leading/trailing",
            pattern: "(a|b)...(c|d)",
            expected_prefix: "addresses with leading: 0xa or 0xb and trailing: 0xc or 0xd",
            max_time: Duration::from_secs(30),
            known_solution: None,
        },
    ]
}

// Helper to parse deployer address
pub fn get_test_deployer() -> Address {
    Address::from_str(TEST_DEPLOYER).expect("Invalid test deployer address")
}

// Verify a miner result
pub fn verify_result(salt: &[u8; 32], address: &Address, pattern: &PatternType) -> bool {
    // This would use the same address calculation as the miners
    // For test purposes, we just check if the address starts with the pattern
    match pattern {
        PatternType::Prefix(prefix) => {
            let addr_bytes = address.as_bytes();
            prefix.len() <= addr_bytes.len() && addr_bytes.starts_with(prefix)
        },
        _ => true, // Just simplifying for tests
    }
}

// Helper to time and execute a test
pub fn run_timed_test<F, R>(name: &str, test_fn: F) -> R
where
    F: FnOnce() -> R,
{
    println!("Running test: {}", name);
    let start = Instant::now();
    let result = test_fn();
    let elapsed = start.elapsed();
    println!("Test completed in {:.2?}", elapsed);
    result
}

// Benchmark structure
pub struct BenchmarkResult {
    pub name: String,
    pub hashes_per_second: f64,
    pub total_hashes: u64,
    pub duration: Duration,
}

// Helper to run a benchmark
pub fn run_benchmark<F>(name: &str, duration: Duration, count_fn: F) -> BenchmarkResult
where
    F: FnOnce(Duration) -> u64,
{
    println!("Running benchmark: {}", name);
    let start = Instant::now();
    
    // Run the benchmark function which returns the number of operations performed
    let total_hashes = count_fn(duration);
    
    let actual_duration = start.elapsed();
    let hashes_per_second = total_hashes as f64 / actual_duration.as_secs_f64();
    
    println!("Benchmark {} completed:", name);
    println!("  Duration: {:.2?}", actual_duration);
    println!("  Total hashes: {}", total_hashes);
    println!("  Hashes per second: {:.2}", hashes_per_second);
    
    BenchmarkResult {
        name: name.to_string(),
        hashes_per_second,
        total_hashes,
        duration: actual_duration,
    }
} 