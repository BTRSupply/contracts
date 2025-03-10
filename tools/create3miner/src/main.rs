use clap::{Parser, ArgGroup};
use std::str::FromStr;
use ethers::prelude::*;
use std::time::Instant;
use create3miner::common::pattern::{parse_pattern, describe_pattern};
use create3miner::cpu::miner::CpuMiner;
use create3miner::gpu::miner::GpuMiner;

#[derive(Parser)]
#[command(author, version, about, long_about = None)]
#[clap(group(ArgGroup::new("mining_method").required(true).args(&["cpu", "gpu"])))]
struct Args {
    /// Pattern to match (supports: hex prefix, regex with | and (...), leading...trailing syntax)
    #[arg(short, long)]
    pattern: String,

    /// Base salt string to use (will be hashed)
    #[arg(short, long)]
    salt: String,

    /// Deployer address (with 0x prefix)
    #[arg(short, long)]
    deployer: String,

    /// Number of threads to use for CPU mining (default: number of logical CPUs)
    #[arg(short, long)]
    threads: Option<usize>,

    /// Stop after finding this many matching salts (default: 1)
    #[arg(short, long, default_value = "1")]
    limit: usize,

    /// Use CPU mining
    #[arg(long, default_value = "false")]
    cpu: bool,

    /// Use GPU mining
    #[arg(long, default_value = "true")]
    gpu: bool,

    /// GPU workgroup size (typically 64, 128, 256)
    #[arg(long, default_value = "256")]
    workgroup_size: u32,
}

fn main() {
    env_logger::init();
    let args = Args::parse();

    // Parse deployer address
    let deployer = Address::from_str(&args.deployer).expect("Invalid deployer address");
    let pattern_str = args.pattern.clone();
    
    // Parse and convert pattern
    let pattern = parse_pattern(&pattern_str);
    
    println!("CREATE3 Salt Miner");
    println!("==================");
    println!("Mining for: {}", describe_pattern(&pattern));
    println!("Deployer: {}", deployer);
    println!("Base salt: {}", args.salt);

    let start_time = Instant::now();
    let results = if args.gpu {
        println!("Mining method: GPU (wgpu)");
        println!("Workgroup size: {}", args.workgroup_size);
        let miner = GpuMiner::new(args.salt, deployer, pattern, args.limit, args.workgroup_size);
        pollster::block_on(miner.mine())
    } else {
        println!("Mining method: CPU");
        let threads = args.threads.unwrap_or_else(|| num_cpus::get());
        println!("Using {} CPU threads", threads);
        let miner = CpuMiner::new(args.salt, deployer, pattern, args.limit, threads);
        miner.mine()
    };

    // Print results
    let elapsed = start_time.elapsed();
    println!("\n=== Mining Results ===");
    println!("Time elapsed: {:.2} seconds", elapsed.as_secs_f64());
    println!("Matching salts found: {}", results.len());
    
    for (i, (salt, address)) in results.iter().enumerate() {
        println!("\nMatch {}:", i + 1);
        println!("Salt: 0x{}", hex::encode(salt));
        println!("Address: {}", address);
    }
}
