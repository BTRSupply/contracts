pub mod common;
pub mod cpu;
pub mod gpu;

// Re-export core functionality for easier imports
pub use common::pattern::{PatternType, address_matches_pattern, parse_pattern, describe_pattern};
pub use cpu::miner::CpuMiner;
pub use gpu::miner::GpuMiner;
