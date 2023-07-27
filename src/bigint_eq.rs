use crate::gpu::single_buffer_compute;
use crate::utils::{split_biguint, limbs_to_bigint256};
use num_bigint::BigUint;
use itertools::Itertools;
use rand::Rng;

#[test]
pub fn test_bigint_eq() {
    let num_inputs = 4;
    let mut a_vals = Vec::with_capacity(num_inputs);
    let mut b_vals = Vec::with_capacity(num_inputs);

    // The scalar field F_r of the Vesta curve:
    let p = BigUint::parse_bytes(b"40000000000000000000000000000000224698fc094cf91b992d30ed00000001", 16).unwrap();

    // Generate input vals
    let mut rng = rand::thread_rng();
    for i in 0..num_inputs {
        let random_bytes = rng.gen::<[u8; 32]>();
        let a = BigUint::from_bytes_be(random_bytes.as_slice()) % &p;

        // Even indices contain different values. Odd indices contain equal values.
        if i % 2 == 0 {
            let random_bytes = rng.gen::<[u8; 32]>();
            let b = BigUint::from_bytes_be(random_bytes.as_slice()) % &p;
            b_vals.push(b.clone());
        } else {
            b_vals.push(a.clone());
        }
        a_vals.push(a.clone());
    }

    let mut expected = Vec::with_capacity(num_inputs);

    // Add each pair of input vals
    for i in 0..num_inputs {
        if &a_vals[i] == &b_vals[i] {
            expected.push(1u32);
        } else{
            expected.push(0u32);
        }
    }

    let mut input_as_bytes: Vec<Vec<u8>> = Vec::with_capacity(num_inputs * 2);
    for i in 0..num_inputs {
        input_as_bytes.push(split_biguint(a_vals[i].clone()));
        input_as_bytes.push(split_biguint(b_vals[i].clone()));
    }

    let input_as_bytes: Vec<u8> = input_as_bytes.into_iter().flatten().collect();

    // Send to the GPU
    let result = pollster::block_on(single_buffer_compute("src/bigint_eq.wgsl", &input_as_bytes, 4)).unwrap();

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
