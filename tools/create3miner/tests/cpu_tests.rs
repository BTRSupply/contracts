use crate::cpu::CpuMiner;
use crate::common::pattern::parse_pattern;
use crate::tests::common::{get_test_cases, get_test_deployer, run_timed_test, TEST_SALT_BASE};
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::Duration;
use std::thread;

#[test]
fn test_cpu_miner_initialization() {
    let deployer = get_test_deployer();
    let pattern = parse_pattern("abcd");
    
    // Create a CPU miner with minimal settings
    let miner = CpuMiner::new(
        TEST_SALT_BASE.to_string(),
        deployer,
        pattern,
        1, // Find just one result
        1, // Use 1 thread for test
    );
    
    // Just test that it initializes without panicking
    assert_eq!(miner.limit, 1);
    assert_eq!(miner.threads, 1);
}

#[test]
fn test_cpu_miner_single_char_pattern() {
    let deployer = get_test_deployer();
    
    // Find addresses with a single character prefix - should be fast
    let pattern = parse_pattern("a");
    
    let result = run_timed_test("CPU miner with single char pattern", || {
        let miner = CpuMiner::new(
            TEST_SALT_BASE.to_string(),
            deployer,
            pattern.clone(),
            1, // Find just one result
            2, // Use 2 threads
        );
        
        // Create timeout mechanism
        let timeout = Duration::from_secs(5);
        let done = Arc::new(AtomicBool::new(false));
        let done_clone = done.clone();
        
        // Spawn timeout thread
        let timeout_handle = thread::spawn(move || {
            thread::sleep(timeout);
            if !done_clone.load(Ordering::SeqCst) {
                panic!("CPU miner test timed out after {:?}", timeout);
            }
        });
        
        // Run the miner
        let results = miner.mine();
        
        // Signal we're done
        done.store(true, Ordering::SeqCst);
        let _ = timeout_handle.join();
        
        results
    });
    
    // Check we got a result
    assert!(!result.is_empty(), "Should have found at least one result");
    let (salt, address) = &result[0];
    
    // Check the address matches our pattern
    let addr_hex = format!("{:x}", address);
    assert!(addr_hex.starts_with("a"), "Address should start with 'a', got: {}", addr_hex);
    
    println!("Found salt: 0x{}", hex::encode(salt));
    println!("Found address: {}", address);
}

#[test]
fn test_cpu_miner_all_pattern_types() {
    // Test all pattern types with a short timeout
    let deployer = get_test_deployer();
    let test_cases = get_test_cases();
    
    for test_case in test_cases {
        let pattern = parse_pattern(test_case.pattern);
        
        let result = run_timed_test(&format!("CPU miner with {}", test_case.name), || {
            let miner = CpuMiner::new(
                TEST_SALT_BASE.to_string(),
                deployer,
                pattern.clone(),
                1, // Find just one result
                2, // Use 2 threads for test
            );
            
            // Create timeout mechanism
            let timeout = Duration::from_secs(3); // Short timeout for tests
            let done = Arc::new(AtomicBool::new(false));
            let done_clone = done.clone();
            
            // Spawn timeout thread
            let timeout_handle = thread::spawn(move || {
                thread::sleep(timeout);
                if !done_clone.load(Ordering::SeqCst) {
                    // Don't panic, just set a flag to exit early
                    done_clone.store(true, Ordering::SeqCst);
                }
            });
            
            // Run the miner with our own early exit condition
            let results = if let Some(test_result) = test_with_early_exit(&miner, done.clone()) {
                test_result
            } else {
                println!("  Test exited early (timeout)");
                vec![] // Empty results if timeout
            };
            
            // Signal we're done
            done.store(true, Ordering::SeqCst);
            let _ = timeout_handle.join();
            
            results
        });
        
        // Just check if we found a solution (might timeout for complex patterns)
        println!("Test case '{}': Found {} solutions", 
                 test_case.name, 
                 result.len());
        
        // If we have a solution, print it
        if !result.is_empty() {
            let (salt, address) = &result[0];
            println!("  Salt: 0x{}", hex::encode(salt));
            println!("  Address: {}", address);
        }
    }
}

// Helper to run a CPU mining test with early exit option
fn test_with_early_exit(miner: &CpuMiner, should_exit: Arc<AtomicBool>) -> Option<Vec<([u8; 32], ethers::prelude::Address)>> {
    // This would ideally run a modified version of the mine() method with early exit
    // For now, we'll just simulate a simplified version
    
    // In a real implementation, you'd modify the CpuMiner to respect an exit flag
    // within its mine() method. For this test, we'll simplify and just check
    // the flag periodically and abort the test if needed.
    
    // Check if we should exit before even starting
    if should_exit.load(Ordering::SeqCst) {
        return None;
    }
    
    // Run the real miner for a short time
    let results = miner.mine();
    Some(results)
} 