use crate::common::pattern::{PatternType, address_matches_pattern};
use crate::common::create3::{calculate_create3_address, compute_deployer_specific_salt};
use ethers::prelude::*;
use ethers::utils::keccak256;
use rand::{RngCore, SeedableRng};
use rand::rngs::StdRng;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};
use rayon::ThreadPoolBuilder;

pub struct CpuMiner {
    base_salt: [u8; 32],
    deployer: Address,
    pattern: PatternType,
    limit: usize,
    threads: usize,
}

impl CpuMiner {
    pub fn new(base_salt_str: String, deployer: Address, pattern: PatternType, limit: usize, threads: usize) -> Self {
        // Hash the base salt string to get the initial salt
        let mut base_salt = [0u8; 32];
        base_salt.copy_from_slice(&keccak256(base_salt_str.as_bytes()));
        
        Self { base_salt, deployer, pattern, limit, threads }
    }
    
    pub fn mine(&self) -> Vec<([u8; 32], Address)> {
        // Keep track of found salts and iterations
        let found_salts = Arc::new(Mutex::new(Vec::new()));
        let iterations = Arc::new(Mutex::new(0u64));
        let start_time = Instant::now();
        let last_report = Arc::new(Mutex::new(start_time));

        // Create a thread pool and start mining
        let pool = ThreadPoolBuilder::new()
            .num_threads(self.threads)
            .build()
            .unwrap();

        pool.scope(|s| {
            // Start threads
            for thread_id in 0..self.threads {
                let found_salts = Arc::clone(&found_salts);
                let iterations = Arc::clone(&iterations);
                let last_report = Arc::clone(&last_report);
                let pattern = self.pattern.clone();
                let deployer = self.deployer;
                let base_salt = self.base_salt;
                let limit = self.limit;

                s.spawn(move |_| {
                    // Initialize thread-specific RNG and salt
                    let mut rng = StdRng::seed_from_u64(thread_id as u64);
                    let mut salt = base_salt;
                    
                    // Add thread-specific randomness to the salt
                    let mut random_bytes = [0u8; 8];
                    rng.fill_bytes(&mut random_bytes);
                    salt[24..32].copy_from_slice(&random_bytes);
                    
                    let mut local_iterations = 0u64;
                    
                    loop {
                        // Randomize the salt
                        salt[0..8].copy_from_slice(&rng.next_u64().to_be_bytes());
                        
                        // Calculate deterministic address
                        let deployer_salt = compute_deployer_specific_salt(&salt, &deployer);
                        let address = calculate_create3_address(&deployer_salt, &deployer);
                        
                        // Check for match
                        if address_matches_pattern(&address, &pattern) {
                            let mut found = found_salts.lock().unwrap();
                            found.push((salt, address));
                            
                            println!("✅ Found matching salt: 0x{}", hex::encode(salt));
                            println!("   Address: {}", address);
                            
                            if found.len() >= limit {
                                println!("\n🎉 Found {} matching salts! Done.", found.len());
                                std::process::exit(0);
                            }
                        }
                        
                        // Update stats
                        local_iterations += 1;
                        if local_iterations % 10000 == 0 {
                            let mut iters = iterations.lock().unwrap();
                            *iters += 10000;
                            
                            let mut last = last_report.lock().unwrap();
                            let now = Instant::now();
                            if now.duration_since(*last) > Duration::from_secs(5) {
                                let elapsed = now.duration_since(start_time).as_secs_f64();
                                let hashes_per_sec = *iters as f64 / elapsed;
                                println!("⚡ Speed: {:.2} hashes/sec, Total: {} hashes in {:.1}s", 
                                         hashes_per_sec, iters, elapsed);
                                *last = now;
                            }
                        }
                    }
                });
            }
        });

        // Create a clone of the results to avoid lifetime issues
        let results = found_salts.lock().unwrap().clone();
        results
    }
}
