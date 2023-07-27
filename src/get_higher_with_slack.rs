//use crate::gpu::single_buffer_compute;
use crate::utils::{limbs_to_bigint256, biguint_to_limbs};
use num_bigint::BigUint;

/*
    var out: BaseField;
    const slack = L - BASE_NBITS;
    for (var i = 0u; i < N; i = i + 1u) {
        out.limbs[i] = ((a.limbs[i + N] << slack) + (a.limbs[i + N - 1] >> (W - slack))) & W_mask;
    }
    return out;
*/
pub fn get_higher_with_slack_impl(a: &BigUint) -> BigUint {
    let n = 16;
    let w = 16;
    let w_mask = 65535;
    let mut out_limbs = vec![0u32; 16];
    let slack = 256 - 255;
    let a_limbs = biguint_to_limbs(&a, 32);
    for i in 0..16 {
        out_limbs[i] = ((a_limbs[i + n] << slack) + (a_limbs[i + n - 1] >> (w - slack))) & w_mask;
    }

    return limbs_to_bigint256(&out_limbs);
}

#[test]
pub fn test_get_higher_with_slack() {
    let a = BigUint::parse_bytes(
        //b"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000000000000000000000000000000000000000",
        b"40000000000000000000000000000000000000000000000000000000000000000",
        16
    ).unwrap();
    println!("a: {:?}", hex::encode(a.to_bytes_be()));
    println!("limbs: {:?}", biguint_to_limbs(&a, 32));
    let a_higher = get_higher_with_slack_impl(&a);
    //println!("h: {:?}", a_higher);
    println!("h: {:?}", hex::encode(a_higher.to_bytes_be()));
    /*
    let num_inputs = 1;
    let mut vals = Vec::with_capacity(num_inputs);

    // The scalar field F_r of the Vesta curve:
    let p = BigUint::parse_bytes(b"40000000000000000000000000000000224698fc094cf91b992d30ed00000001", 16).unwrap();

    // Generate input vals
    for _ in 0..num_inputs {
        let mut rng = rand::thread_rng();
        let random_bytes = rng.gen::<[u8; 32]>();
        let a = BigUint::from_bytes_be(random_bytes.as_slice()) % &p;
        vals.push(a)
    }

    let mut expected = Vec::with_capacity(num_inputs);

    // Compute get_higher_with_slack() for each val
    for val in &vals {
        expected.push(get_higher_with_slack_impl(val.clone()));
    }
    **********/

    /*
    let mut input_as_bytes: Vec<Vec<u8>> = Vec::with_capacity(num_inputs);
    for val in &vals {
        input_as_bytes.push(split_biguint(val.clone()));
    }

    let input_as_bytes: Vec<u8> = input_as_bytes.into_iter().flatten().collect();

    // Send to the GPU
    let result = pollster::block_on(get_higher_with_slack(&input_as_bytes)).unwrap();

    let chunks: Vec<Vec<u32>> = result
        .into_iter().chunks(16)
        .into_iter().map(|c| c.into_iter().collect())
        .collect();

    let results_as_biguint: Vec<BigUint> = chunks.iter().map(|c| limbs_to_bigint256(c)).collect();

    for i in 0..num_inputs {
        assert_eq!(results_as_biguint[i], expected[i]);
    }
    */
}
