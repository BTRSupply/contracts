use crate::common::pattern::{PatternType, get_pattern_for_gpu};
use crate::common::create3::PROXY_INITCODE_HASH;
use bytemuck::{Pod, Zeroable};
use ethers::prelude::*;
use ethers::utils::keccak256;
use std::borrow::Cow;
use wgpu::util::DeviceExt;
use log::info;
use std::time::Instant;

// Simplified WGSL Shader for salt mining
const SHADER_SOURCE: &str = include_str!("shader.wgsl");

// GPU buffer structures
#[repr(C)]
#[derive(Debug, Copy, Clone, Pod, Zeroable)]
struct GpuSalt { bytes: [u8; 32] }

#[repr(C)]
#[derive(Debug, Copy, Clone, Pod, Zeroable)]
#[allow(dead_code)]
struct GpuAddress { bytes: [u8; 20] }

#[repr(C)]
#[derive(Debug, Copy, Clone, Pod, Zeroable)]
struct GpuDeployer { bytes: [u8; 20] }

#[repr(C)]
#[derive(Debug, Copy, Clone, Pod, Zeroable)]
struct GpuPatternInfo {
    pattern_type: u32, // 0=prefix, 1=regex, 2=advanced
    has_leading: u32,
    has_trailing: u32,
    option_count: u32,
}

pub struct GpuMiner {
    base_salt: [u8; 32],
    deployer: Address,
    pattern: PatternType,
    limit: usize,
    workgroup_size: u32,
}

impl GpuMiner {
    pub fn new(base_salt_str: String, deployer: Address, pattern: PatternType, limit: usize, workgroup_size: u32) -> Self {
        let mut base_salt = [0u8; 32];
        base_salt.copy_from_slice(&keccak256(base_salt_str.as_bytes()));
        
        Self { base_salt, deployer, pattern, limit, workgroup_size }
    }
    
    pub async fn mine(&self) -> Vec<([u8; 32], Address)> {
        // Initialize GPU
        let instance = wgpu::Instance::new(&wgpu::InstanceDescriptor {
            backends: wgpu::Backends::all(),
            ..Default::default()
        });
        
        // Request GPU adapter
        info!("Requesting GPU adapter");
        let adapter = instance
            .request_adapter(&wgpu::RequestAdapterOptions {
                power_preference: wgpu::PowerPreference::HighPerformance,
                compatible_surface: None,
                force_fallback_adapter: false,
            })
            .await
            .expect("Failed to find an appropriate adapter");
            
        // Log adapter info
        let adapter_info = adapter.get_info();
        info!("Using adapter: {} ({})", adapter_info.name, adapter_info.backend.to_str());
        
        // Create device and queue
        let (device, queue) = adapter
            .request_device(
                &wgpu::DeviceDescriptor {
                    label: Some("Salt Miner"),
                    required_features: wgpu::Features::empty(),
                    required_limits: wgpu::Limits::default(),
                    memory_hints: Default::default(),
                },
                None,
            )
            .await
            .expect("Failed to create device");
            
        // Create shader and pipeline
        let shader = device.create_shader_module(wgpu::ShaderModuleDescriptor {
            label: Some("Salt Mining Shader"),
            source: wgpu::ShaderSource::Wgsl(Cow::Borrowed(SHADER_SOURCE)),
        });
            
        let compute_pipeline = device.create_compute_pipeline(&wgpu::ComputePipelineDescriptor {
            label: Some("Salt Mining Pipeline"),
            layout: None,
            module: &shader,
            entry_point: Some("main"),
            compilation_options: Default::default(),
            cache: None,
        });

        // Get pattern for GPU
        let (pattern_prefix, _) = get_pattern_for_gpu(&self.pattern);
        
        // Configure batch size
        let batch_size = 1_000_000; // Process 1M salts per batch
        let workgroup_count = batch_size / self.workgroup_size;
        
        // Create buffers
        let base_salt_buffer = device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
            label: Some("Base Salt Buffer"),
            contents: bytemuck::cast_slice(&[GpuSalt { bytes: self.base_salt }]),
            usage: wgpu::BufferUsages::STORAGE | wgpu::BufferUsages::COPY_DST,
        });
        
        let deployer_buffer = device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
            label: Some("Deployer Buffer"),
            contents: bytemuck::cast_slice(&[GpuDeployer { bytes: self.deployer.0 }]),
            usage: wgpu::BufferUsages::STORAGE | wgpu::BufferUsages::COPY_DST,
        });
        
        let proxy_initcode_hash_buffer = device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
            label: Some("Proxy Initcode Hash Buffer"),
            contents: bytemuck::cast_slice(&PROXY_INITCODE_HASH),
            usage: wgpu::BufferUsages::STORAGE | wgpu::BufferUsages::COPY_DST,
        });

        // Setup pattern info
        let pattern_info = GpuPatternInfo {
            pattern_type: match &self.pattern {
                PatternType::Prefix(_) => 0,
                PatternType::Regex(_) => 1,
                PatternType::Advanced { .. } => 2,
            },
            has_leading: if let PatternType::Advanced { leading, .. } = &self.pattern {
                if leading.is_some() { 1 } else { 0 }
            } else { 0 },
            has_trailing: if let PatternType::Advanced { trailing, .. } = &self.pattern {
                if trailing.is_some() { 1 } else { 0 }
            } else { 0 },
            option_count: 0,
        };
    
        let pattern_info_buffer = device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
            label: Some("Pattern Info Buffer"),
            contents: bytemuck::cast_slice(&[pattern_info]),
            usage: wgpu::BufferUsages::STORAGE | wgpu::BufferUsages::COPY_DST,
        });
    
        // Create pattern data buffer
        let mut pattern_data = vec![0u8; 32]; // Max prefix length
        if !pattern_prefix.is_empty() {
            pattern_data[..pattern_prefix.len()].copy_from_slice(&pattern_prefix);
        }
    
        let pattern_data_buffer = device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
            label: Some("Pattern Data Buffer"),
            contents: bytemuck::cast_slice(&pattern_data),
            usage: wgpu::BufferUsages::STORAGE | wgpu::BufferUsages::COPY_DST,
        });
        
        // Create output buffers
        let result_buffer = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("Result Buffer"),
            size: (batch_size * (32 + 20)) as u64, // salt + address
            usage: wgpu::BufferUsages::STORAGE | wgpu::BufferUsages::COPY_SRC,
            mapped_at_creation: false,
        });
        
        let match_buffer = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("Match Flag Buffer"),
            size: (batch_size * 4) as u64, // u32 flag per work item
            usage: wgpu::BufferUsages::STORAGE | wgpu::BufferUsages::COPY_SRC,
            mapped_at_creation: false,
        });
        
        // Create staging buffer for reading results
        let staging_buffer = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("Staging Buffer"),
            size: (batch_size * 4) as u64, // Just need the match flags initially
            usage: wgpu::BufferUsages::MAP_READ | wgpu::BufferUsages::COPY_DST,
            mapped_at_creation: false,
        });
        
        // Create bind group
        let bind_group_layout = compute_pipeline.get_bind_group_layout(0);
        let bind_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
            label: Some("Salt Miner Bind Group"),
            layout: &bind_group_layout,
            entries: &[
                wgpu::BindGroupEntry { binding: 0, resource: base_salt_buffer.as_entire_binding() },
                wgpu::BindGroupEntry { binding: 1, resource: deployer_buffer.as_entire_binding() },
                wgpu::BindGroupEntry { binding: 2, resource: proxy_initcode_hash_buffer.as_entire_binding() },
                wgpu::BindGroupEntry { binding: 3, resource: result_buffer.as_entire_binding() },
                wgpu::BindGroupEntry { binding: 4, resource: match_buffer.as_entire_binding() },
                wgpu::BindGroupEntry { binding: 5, resource: pattern_info_buffer.as_entire_binding() },
                wgpu::BindGroupEntry { binding: 6, resource: pattern_data_buffer.as_entire_binding() },
            ],
        });
        
        // Prepare to collect results
        let mut results = Vec::new();
        let mut batch_nonce = 0u64;
        let start_time = Instant::now();
        let mut last_report_time = start_time;
        let mut total_hashes = 0u64;
        
        // Mining loop
        loop {
            if results.len() >= self.limit {
                break;
            }
            
            // Update base salt with batch nonce to ensure we're trying different salts each batch
            queue.write_buffer(
                &base_salt_buffer,
                0,
                bytemuck::cast_slice(&[batch_nonce.to_be_bytes()]),
            );
            
            // Create command encoder for this batch
            let mut encoder = device.create_command_encoder(&wgpu::CommandEncoderDescriptor {
                label: Some("Mining Batch Encoder"),
            });
            
            // Run compute shader
            {
                let mut compute_pass = encoder.begin_compute_pass(&wgpu::ComputePassDescriptor {
                    label: Some("Salt Mining Pass"),
                    timestamp_writes: None,
                });
                compute_pass.set_pipeline(&compute_pipeline);
                compute_pass.set_bind_group(0, &bind_group, &[]);
                compute_pass.dispatch_workgroups(workgroup_count, 1, 1);
            }
            
            // Copy match flags to staging buffer for CPU access
            encoder.copy_buffer_to_buffer(
                &match_buffer,
                0,
                &staging_buffer,
                0,
                (batch_size * 4) as u64,
            );
            
            // Submit GPU commands
            queue.submit(Some(encoder.finish()));
            
            // Read match flags from staging buffer
            let buffer_slice = staging_buffer.slice(..);
            let _ = buffer_slice;  // Instead of drop()
            
            // Check for matches
            let buffer_slice = staging_buffer.slice(..);
            let (sender, receiver) = futures::channel::oneshot::channel();
            buffer_slice.map_async(wgpu::MapMode::Read, move |v| sender.send(v).unwrap());
            
            device.poll(wgpu::Maintain::Wait);
            
            if let Ok(Ok(_)) = receiver.await {
                let data = buffer_slice.get_mapped_range();
                let match_flags: &[u32] = bytemuck::cast_slice(&data);
                
                // Find match indices
                let matches: Vec<usize> = match_flags
                    .iter()
                    .enumerate()
                    .filter(|(_, &flag)| flag == 1)
                    .map(|(idx, _)| idx)
                    .collect();
                
                // If we found matches, read the result buffer to get the salts and addresses
                if !matches.is_empty() {
                    info!("Found {} matches in batch {}", matches.len(), batch_nonce);
                    
                    // Create a buffer to read results from GPU
                    let read_size = matches.len() * (32 + 20);
                    let staging_buffer_result = device.create_buffer(&wgpu::BufferDescriptor {
                        label: Some("Result Staging Buffer"),
                        size: read_size as u64,
                        usage: wgpu::BufferUsages::COPY_DST | wgpu::BufferUsages::MAP_READ,
                        mapped_at_creation: false,
                    });
                    
                    // For each match, copy the result data to staging buffer
                    for (i, &idx) in matches.iter().enumerate() {
                        let mut encoder = device.create_command_encoder(&wgpu::CommandEncoderDescriptor {
                            label: Some("Result Copy Encoder"),
                        });
                        
                        encoder.copy_buffer_to_buffer(
                            &result_buffer,
                            (idx * (32 + 20)) as u64,
                            &staging_buffer_result,
                            (i * (32 + 20)) as u64,
                            (32 + 20) as u64,
                        );
                        
                        queue.submit(Some(encoder.finish()));
                    }
                    
                    // Read results
                    let buffer_slice = staging_buffer_result.slice(..);
                    let (sender, receiver) = futures::channel::oneshot::channel();
                    buffer_slice.map_async(wgpu::MapMode::Read, move |v| sender.send(v).unwrap());
                    
                    device.poll(wgpu::Maintain::Wait);
                    
                    if let Ok(Ok(_)) = receiver.await {
                        let data = buffer_slice.get_mapped_range();
                        
                        for i in 0..matches.len() {
                            let offset = i * (32 + 20);
                            
                            // Extract salt
                            let mut salt = [0u8; 32];
                            salt.copy_from_slice(&data[offset..offset + 32]);
                            
                            // Extract address
                            let mut addr_bytes = [0u8; 20];
                            addr_bytes.copy_from_slice(&data[offset + 32..offset + 32 + 20]);
                            let address = Address::from_slice(&addr_bytes);
                            
                            results.push((salt, address));
                            println!("✅ Found matching salt: 0x{}", hex::encode(salt));
                            println!("   Address: {}", address);
                            
                            if results.len() >= self.limit {
                                break;
                            }
                        }
                    }
                    
                    // Unmap the result buffer
                    drop(data);
                    staging_buffer_result.unmap();
                }
            }
            
            // Unmap the staging buffer
            let _ = buffer_slice;
            staging_buffer.unmap();
            
            // Update stats
            batch_nonce += 1;
            total_hashes += batch_size as u64;
            
            let now = Instant::now();
            if now.duration_since(last_report_time).as_secs() >= 5 {
                let elapsed = now.duration_since(start_time).as_secs_f64();
                let hashes_per_sec = total_hashes as f64 / elapsed;
                
                println!("⚡ Speed: {:.2} hashes/sec, Total: {} batches ({} hashes) in {:.1}s", 
                         hashes_per_sec, batch_nonce, total_hashes, elapsed);
                last_report_time = now;
            }
        }
        
        println!("\n🎉 Found {} matching salts! Done.", results.len());
        results
    }
}
