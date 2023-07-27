use crate::gpu::single_buffer_compute;
use crate::utils::{split_biguint, limbs_to_bigint256};
use num_bigint::BigUint;
use num_bigint::RandBigInt;
use stopwatch::Stopwatch;
use itertools::Itertools;

#[test]
pub fn test_bigint_double() {
    let num_inputs = 4096;
    let mut vals = Vec::with_capacity(num_inputs);

    // Generate input vals
    for _ in 0..num_inputs {
        let mut rng = rand::thread_rng();
        vals.push(rng.gen_biguint(64));
    }

    let mut expected = Vec::with_capacity(num_inputs);

    // Double each input val
    let sw = Stopwatch::start_new();
    for val in &vals {
        expected.push(val + val);
    }
    println!("CPU took {}ms", sw.elapsed_ms());

    let mut input_as_bytes: Vec<Vec<u8>> = Vec::with_capacity(num_inputs);
    for val in &vals {
        input_as_bytes.push(split_biguint(val.clone()));
    }

    let input_as_bytes: Vec<u8> = input_as_bytes.into_iter().flatten().collect();

    // Send to the GPU
    let result = pollster::block_on(single_buffer_compute("src/bigint_double.wgsl", &input_as_bytes, 16)).unwrap();

    let chunks: Vec<Vec<u32>> = result
        .into_iter().chunks(16)
        .into_iter().map(|c| c.into_iter().collect())
        .collect();

    let results_as_biguint: Vec<BigUint> = chunks.iter().map(|c| limbs_to_bigint256(c)).collect();

    for i in 0..num_inputs {
        assert_eq!(results_as_biguint[i], expected[i]);
    }
}
