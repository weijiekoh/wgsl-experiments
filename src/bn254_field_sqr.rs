use crate::gpu::single_buffer_compute;
use crate::utils::{split_biguint, limbs_to_bigint256};
use num_bigint::BigUint;
use itertools::Itertools;
use rand::Rng;

#[test]
pub fn test_field_sqr() {
    let num_inputs = 1;
    let mut a_vals: Vec<BigUint> = Vec::with_capacity(num_inputs);

    // The scalar field F_r of the BN254 curve:
    // 21888242871839275222246405745257275088548364400416034343698204186575808495617
    let p = BigUint::parse_bytes(b"30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001", 16).unwrap();
    
    //let mu = BigUint::parse_bytes(b"54a47462623a04a7ab074a58680730147144852009e880ae620703a6be1de925", 16).unwrap();
    //let limbs: Vec<u32> = bigint_to_limbs(&mu);
    //println!("{:?}", limbs);
 
    // Generate input vals
    let mut rng = rand::thread_rng();
    for _ in 0..num_inputs {
        let random_bytes = rng.gen::<[u8; 32]>();
        let a = BigUint::from_bytes_be(random_bytes.as_slice()) % &p;
        assert!(a < p);
        a_vals.push(a);
    }

    let mut expected: Vec<BigUint> = Vec::with_capacity(num_inputs);

    for i in 0..num_inputs {
        let e = (&a_vals[i] * &a_vals[i]) % &p;
        assert!(e < p);
        expected.push(e);
    }

    let mut input_as_bytes: Vec<Vec<u8>> = Vec::with_capacity(num_inputs);
    for i in 0..num_inputs {
        input_as_bytes.push(split_biguint(a_vals[i].clone()));
    }

    let input_as_bytes: Vec<u8> = input_as_bytes.into_iter().flatten().collect();

    // Send to the GPU
    let result = pollster::block_on(single_buffer_compute("src/bn254_field_sqr.wgsl", &input_as_bytes, 1)).unwrap();

    let chunks: Vec<Vec<u32>> = result
        .into_iter().chunks(16)
        .into_iter().map(|c| c.into_iter().collect())
        .collect();

    let results_as_biguint: Vec<BigUint> = chunks.iter().map(|c| limbs_to_bigint256(c)).collect();

    //println!("a: {:?}", a_vals);
    //println!("e: {:?}", expected);
    //println!("r: {:?}", results_as_biguint);

    for i in 0..num_inputs {
        assert_eq!(results_as_biguint[i], expected[i]);
    }
}
