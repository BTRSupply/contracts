use ethers::prelude::*;
use ethers::utils::keccak256;

// Constants from CREATE3.sol
pub const PROXY_INITCODE_HASH: [u8; 32] = [
    0x21, 0xc3, 0x5d, 0xbe, 0x1b, 0x34, 0x4a, 0x24, 0x88, 0xcf, 0x33, 0x21, 
    0xd6, 0xce, 0x54, 0x2f, 0x8e, 0x9f, 0x30, 0x55, 0x44, 0xff, 0x09, 0xe4, 
    0x99, 0x3a, 0x62, 0x31, 0x9a, 0x49, 0x7c, 0x1f
];

/// Calculate CREATE3 deterministic address based on salt and deployer
pub fn calculate_create3_address(salt: &[u8; 32], deployer: &Address) -> Address {
    // Step 1: Calculate the CREATE2 proxy address
    let mut input = vec![0xff]; // 0xff prefix for CREATE2
    input.extend_from_slice(&deployer.as_bytes());
    input.extend_from_slice(salt);
    input.extend_from_slice(&PROXY_INITCODE_HASH);
    
    let proxy_address_hash = keccak256(&input);
    let mut proxy_address = [0u8; 20];
    proxy_address.copy_from_slice(&proxy_address_hash[12..32]);
    
    // Step 2: Calculate the CREATE address from the proxy (with nonce 1)
    let mut rlp_data = vec![0xd6, 0x94]; // RLP encoding prefix
    rlp_data.extend_from_slice(&proxy_address);
    rlp_data.push(0x01); // Nonce = 1
    
    let deployed_address_hash = keccak256(&rlp_data);
    let mut deployed_address = [0u8; 20];
    deployed_address.copy_from_slice(&deployed_address_hash[12..32]);
    
    Address::from_slice(&deployed_address)
}

/// Calculate deployer-specific salt by combining original salt with deployer
pub fn compute_deployer_specific_salt(salt: &[u8; 32], deployer: &Address) -> [u8; 32] {
    let mut input = Vec::with_capacity(salt.len() + deployer.as_bytes().len());
    input.extend_from_slice(salt);
    input.extend_from_slice(&deployer.as_bytes());
    
    let mut output = [0u8; 32];
    output.copy_from_slice(&keccak256(&input));
    output
} 