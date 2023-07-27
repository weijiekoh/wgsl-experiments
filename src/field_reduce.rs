use crate::gpu::single_buffer_compute;
use crate::utils::{split_biguint, limbs_to_bigint256};
use num_bigint::BigUint;
use num_bigint::RandBigInt;
use itertools::Itertools;

#[test]
pub fn test_field_reduce() {
    let num_inputs = 2;
    let mut vals: Vec<BigUint> = Vec::with_capacity(num_inputs);

    // The BN254 F_p field order is 21888242871839275222246405745257275088696311157297823662689037894645226208583
    //let p = BigUint::parse_bytes(b"30644e72e131a029b85045b68181585d97816a916871ca8d3c208c16d87cfd47", 16).unwrap();

    // The scalar field F_r of the Vesta curve:
    let p = BigUint::parse_bytes(b"40000000000000000000000000000000224698fc094cf91b992d30ed00000001", 16).unwrap();
    let lim = BigUint::parse_bytes(b"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff", 16).unwrap();

    // Generate input vals
    let mut rng = rand::thread_rng();
    for _ in 0..num_inputs {
        loop {
            let r = rng.gen_biguint(64);
            let val = &p + &r; 
            if val < lim {
                vals.push(val);
                break;
            }
        }
    }

    let mut expected: Vec<BigUint> = Vec::with_capacity(num_inputs);

    for val in &vals {
        expected.push(val % &p);
    }

    let mut input_as_bytes: Vec<Vec<u8>> = Vec::with_capacity(num_inputs);
    for val in &vals {
        input_as_bytes.push(split_biguint(val.clone()));
    }

    let input_as_bytes: Vec<u8> = input_as_bytes.into_iter().flatten().collect();

    // Send to the GPU
    let result = pollster::block_on(single_buffer_compute("src/field_reduce.wgsl", &input_as_bytes, 1)).unwrap();

    let chunks: Vec<Vec<u32>> = result
        .into_iter().chunks(16)
        .into_iter().map(|c| c.into_iter().collect())
        .collect();

    let results_as_biguint: Vec<BigUint> = chunks.iter().map(|c| limbs_to_bigint256(c)).collect();

    //println!("input: {:?}", vals);
    //println!("expected: {:?}", expected);
    //println!("results: {:?}", results_as_biguint);

    for i in 0..num_inputs {
        assert_eq!(results_as_biguint[i], expected[i]);
    }
}
