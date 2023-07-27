use crate::gpu::single_buffer_compute;
use crate::utils::{split_biguint, limbs_to_bigint256};
use num_bigint::BigUint;
use itertools::Itertools;
use rand::Rng;

#[test]
pub fn test_bigint_cmp() {
    let num_inputs = 4;
    let mut a_vals = Vec::with_capacity(num_inputs);
    let mut b_vals = Vec::with_capacity(num_inputs);

    // The scalar field F_r of the Vesta curve:
    let p = BigUint::parse_bytes(b"40000000000000000000000000000000224698fc094cf91b992d30ed00000001", 16).unwrap();

    // Generate input vals
    let mut rng = rand::thread_rng();
    for i in 0..num_inputs {
        let random_bytes = rng.gen::<[u8; 1]>();
        let a = BigUint::from_bytes_be(random_bytes.as_slice()) % &p;
        let random_bytes = rng.gen::<[u8; 1]>();
        let b = BigUint::from_bytes_be(random_bytes.as_slice()) % &p;
        
        assert!(a < p);
        assert!(b < p);
        
        let mut larger = a.clone();
        let mut smaller = b.clone();

        if a < b {
            larger = b.clone();
            smaller = a.clone();
        }

        let m = i % 4;
        if m == 0 || m == 1 {
            // a > b
            a_vals.push(larger);
            b_vals.push(smaller);
        } else if m == 2 {
            // a < b
            a_vals.push(smaller);
            b_vals.push(larger);
        } else if m == 3 {
            // a == b
            a_vals.push(smaller.clone());
            b_vals.push(smaller.clone());
        }
    }

    let mut expected = Vec::with_capacity(num_inputs);

    // Add each pair of input vals
    for i in 0..num_inputs {
        // a < b --> 0
        // a == b --> 1
        // a > b --> 2
        if &a_vals[i] < &b_vals[i] {
            expected.push(0u32);
        } else if &a_vals[i] == &b_vals[i] {
            expected.push(1u32);
        } else if &a_vals[i] > &b_vals[i] {
            expected.push(2u32);
        }
    }

    let mut input_as_bytes: Vec<Vec<u8>> = Vec::with_capacity(num_inputs * 2);
    for i in 0..num_inputs {
        input_as_bytes.push(split_biguint(a_vals[i].clone()));
        input_as_bytes.push(split_biguint(b_vals[i].clone()));
    }

    let input_as_bytes: Vec<u8> = input_as_bytes.into_iter().flatten().collect();

    // Send to the GPU
    //let result = pollster::block_on(bigint_cmp(&input_as_bytes)).unwrap();
    let result = pollster::block_on(single_buffer_compute("src/bigint_cmp.wgsl", &input_as_bytes, 1)).unwrap();

    let chunks: Vec<Vec<u32>> = result
        .into_iter().chunks(16)
        .into_iter().map(|c| c.into_iter().collect())
        .collect();

    let results_as_biguint: Vec<BigUint> = chunks.iter().map(|c| limbs_to_bigint256(c)).collect();

    //println!("a: {:?}", a_vals);
    //println!("b: {:?}", b_vals);
    //println!("e: {:?}", expected);
    //println!("r: {:?}", results_as_biguint);

    for i in 0..num_inputs {
        assert_eq!(results_as_biguint[i * 2], BigUint::from_slice(&[expected[i]]));
    }
}
