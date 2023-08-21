use crate::gpu::single_buffer_compute;
use crate::utils::{split_biguint, limbs_to_bigint256};
use num_bigint::BigUint;
use num_bigint::RandBigInt;
use stopwatch::Stopwatch;
use itertools::Itertools;
use rand::Rng;

#[test]
pub fn test_bigint_sub() {
    let num_inputs = 2;
    let mut a_vals = Vec::with_capacity(num_inputs);
    let mut b_vals = Vec::with_capacity(num_inputs);

    // The scalar field F_r of the Vesta curve:
    let p = BigUint::parse_bytes(b"40000000000000000000000000000000224698fc094cf91b992d30ed00000001", 16).unwrap();

    // Generate input vals
    for _ in 0..num_inputs {
        let mut rng = rand::thread_rng();
        let random_bytes = rng.gen::<[u8; 32]>();
        let x = BigUint::from_bytes_be(random_bytes.as_slice()) % &p;
        let random_bytes = rng.gen::<[u8; 32]>();
        let y = BigUint::from_bytes_be(random_bytes.as_slice()) % &p;
        if x > y {
            a_vals.push(x);
            b_vals.push(y);
        } else {
            a_vals.push(y);
            b_vals.push(x);
        }
    }

    let mut expected = Vec::with_capacity(num_inputs);

    // Subtract each pair of input vals
    let sw = Stopwatch::start_new();
    for i in 0..num_inputs {
        expected.push(&a_vals[i] - &b_vals[i]);
    }
    println!("CPU took {}ms", sw.elapsed_ms());

    let mut input_as_bytes: Vec<Vec<u8>> = Vec::with_capacity(num_inputs * 2);
    for i in 0..num_inputs {
        input_as_bytes.push(split_biguint(a_vals[i].clone()));
        input_as_bytes.push(split_biguint(b_vals[i].clone()));
    }

    let input_as_bytes: Vec<u8> = input_as_bytes.into_iter().flatten().collect();

    // Send to the GPU
    //let result = pollster::block_on(bigint_sub(&input_as_bytes)).unwrap();
    let result = pollster::block_on(single_buffer_compute("src/bigint_sub.wgsl", &input_as_bytes, 1)).unwrap();

    let chunks: Vec<Vec<u32>> = result
        .into_iter().chunks(16)
        .into_iter().map(|c| c.into_iter().collect())
        .collect();

    let results_as_biguint: Vec<BigUint> = chunks.iter().map(|c| limbs_to_bigint256(c)).collect();

    for i in 0..num_inputs {
        assert_eq!(results_as_biguint[i * 2], expected[i]);
    }
}
