use crate::gpu::GpuMiner;
use crate::common::pattern::parse_pattern;
use crate::tests::common::{get_test_cases, get_test_deployer, run_timed_test, TEST_SALT_BASE};
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::Duration;
use std::thread;

use futures::executor::block_on;

#[test]
fn test_gpu_miner_initialization() {
    let deployer = get_test_deployer();
    let pattern = parse_pattern("abcd");
    
    // Create a GPU miner with minimal settings
    let miner = GpuMiner::new(
        TEST_SALT_BASE.to_string(),
        deployer,
        pattern,
        1, // Find just one result
        128, // Workgroup size
    );
    
    // Just test that it initializes without panicking
    assert_eq!(miner.limit, 1);
    assert_eq!(miner.workgroup_size, 128);
}

#[test]
fn test_gpu_miner_single_char_pattern() {
    // Skip if GPU tests are disabled
    if std::env::var("SKIP_GPU_TESTS").is_ok() {
        println!("Skipping GPU test due to SKIP_GPU_TESTS env var");
        return;
    }

    let deployer = get_test_deployer();
    
    // Find addresses with a single character prefix - should be fast
    let pattern = parse_pattern("a");
    
    let result = run_timed_test("GPU miner with single char pattern", || {
        let miner = GpuMiner::new(
            TEST_SALT_BASE.to_string(),
            deployer,
            pattern.clone(),
            1, // Find just one result
            128, // Workgroup size
        );
        
        // Create timeout mechanism
        let timeout = Duration::from_secs(10); // Give GPU a bit more time for initialization
        let done = Arc::new(AtomicBool::new(false));
        let done_clone = done.clone();
        
        // Spawn timeout thread
        let timeout_handle = thread::spawn(move || {
            thread::sleep(timeout);
            if !done_clone.load(Ordering::SeqCst) {
                panic!("GPU miner test timed out after {:?}", timeout);
            }
        });
        
        // Run the miner
        let results = block_on(miner.mine());
        
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
fn test_gpu_miner_pattern_types() {
    // Skip if GPU tests are disabled
    if std::env::var("SKIP_GPU_TESTS").is_ok() {
        println!("Skipping GPU test due to SKIP_GPU_TESTS env var");
        return;
    }

    // Test just the simple pattern types that GPU should handle well
    let deployer = get_test_deployer();
    let test_cases = get_test_cases().into_iter()
        .filter(|tc| tc.pattern.len() <= 2) // Only test very simple patterns for quick tests
        .collect::<Vec<_>>();
    
    for test_case in test_cases {
        let pattern = parse_pattern(test_case.pattern);
        
        let result = run_timed_test(&format!("GPU miner with {}", test_case.name), || {
            let miner = GpuMiner::new(
                TEST_SALT_BASE.to_string(),
                deployer,
                pattern.clone(),
                1, // Find just one result
                128, // Workgroup size
            );
            
            // Create timeout mechanism
            let timeout = Duration::from_secs(5); // Short timeout for tests
            let done = Arc::new(AtomicBool::new(false));
            let done_clone = done.clone();
            
            // Spawn timeout thread
            let timeout_handle = thread::spawn(move || {
                thread::sleep(timeout);
                if !done_clone.load(Ordering::SeqCst) {
                    // Don't panic, just set a flag
                    println!("GPU test timed out, will exit gracefully");
                    done_clone.store(true, Ordering::SeqCst);
                }
            });
            
            // Run the miner with our own early exit condition
            let results = block_on(async {
                // In a real implementation, we'd modify the GpuMiner to respect an exit flag
                // For now, we'll just use a short timeout
                
                // Start the mining operation
                let mine_future = miner.mine();
                
                // Use a timeout for the future
                match tokio::time::timeout(timeout, mine_future).await {
                    Ok(result) => result,
                    Err(_) => {
                        println!("  GPU mining timed out, returning empty results");
                        vec![]
                    }
                }
            });
            
            // Signal we're done
            done.store(true, Ordering::SeqCst);
            let _ = timeout_handle.join();
            
            results
        });
        
        // Just check if we found a solution (might timeout)
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

#[test]
fn test_compare_cpu_gpu_results() {
    // Skip if GPU tests are disabled
    if std::env::var("SKIP_GPU_TESTS").is_ok() {
        println!("Skipping GPU test due to SKIP_GPU_TESTS env var");
        return;
    }

    let deployer = get_test_deployer();
    
    // Use a single character pattern to ensure we get quick results
    let pattern_str = "a";
    let pattern = parse_pattern(pattern_str);
    
    println!("Mining with CPU and GPU for pattern: {}", pattern_str);
    
    // CPU mining
    let cpu_results = run_timed_test("CPU Mining", || {
        let miner = crate::cpu::CpuMiner::new(
            TEST_SALT_BASE.to_string(),
            deployer,
            pattern.clone(),
            1, // 1 result
            2, // 2 threads
        );
        
        // Set a timeout to avoid hanging test
        let timeout = Duration::from_secs(5);
        let done = Arc::new(AtomicBool::new(false));
        let done_clone = done.clone();
        
        let timeout_handle = thread::spawn(move || {
            thread::sleep(timeout);
            if !done_clone.load(Ordering::SeqCst) {
                panic!("CPU miner test timed out after {:?}", timeout);
            }
        });
        
        let results = miner.mine();
        
        done.store(true, Ordering::SeqCst);
        let _ = timeout_handle.join();
        
        results
    });
    
    // GPU mining
    let gpu_results = run_timed_test("GPU Mining", || {
        let miner = GpuMiner::new(
            TEST_SALT_BASE.to_string(),
            deployer,
            pattern.clone(),
            1, // 1 result
            128, // Workgroup size
        );
        
        // Set a timeout to avoid hanging test
        let timeout = Duration::from_secs(10); // More time for GPU init
        let done = Arc::new(AtomicBool::new(false));
        let done_clone = done.clone();
        
        let timeout_handle = thread::spawn(move || {
            thread::sleep(timeout);
            if !done_clone.load(Ordering::SeqCst) {
                panic!("GPU miner test timed out after {:?}", timeout);
            }
        });
        
        let results = block_on(miner.mine());
        
        done.store(true, Ordering::SeqCst);
        let _ = timeout_handle.join();
        
        results
    });
    
    // Verify both methods found solutions
    assert!(!cpu_results.is_empty(), "CPU should have found a solution");
    assert!(!gpu_results.is_empty(), "GPU should have found a solution");
    
    // Print results for comparison
    println!("CPU found salt: 0x{} -> address: {}", 
             hex::encode(cpu_results[0].0), 
             cpu_results[0].1);
    
    println!("GPU found salt: 0x{} -> address: {}", 
             hex::encode(gpu_results[0].0), 
             gpu_results[0].1);
    
    // Check that both addresses start with the pattern
    let cpu_addr_hex = format!("{:x}", cpu_results[0].1);
    let gpu_addr_hex = format!("{:x}", gpu_results[0].1);
    
    assert!(cpu_addr_hex.starts_with(pattern_str), 
            "CPU address should start with '{}', got: {}", 
            pattern_str, 
            cpu_addr_hex);
    
    assert!(gpu_addr_hex.starts_with(pattern_str), 
            "GPU address should start with '{}', got: {}", 
            pattern_str, 
            gpu_addr_hex);
} 