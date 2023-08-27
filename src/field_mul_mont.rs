//use ark_bn254::Fr;
//use ark_ff::fields::Field;
use crate::gpu::single_buffer_compute;
use crate::utils::{split_biguint, limbs_to_bigint256};
use num_bigint::BigUint;
use itertools::Itertools;
use rand::Rng;

#[test]
pub fn test_field_mul_mont() {
    let num_inputs = 32;
    let mut a_vals: Vec<BigUint> = Vec::with_capacity(num_inputs);
    let mut b_vals: Vec<BigUint> = Vec::with_capacity(num_inputs);

    // The BN254 F_r field order
    let p = BigUint::parse_bytes(b"30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001", 16).unwrap();
    //let r = BigUint::parse_bytes(b"10000000000000000000000000000000000000000000000000000000000000000", 16).unwrap();
    let rinv = BigUint::parse_bytes(b"15ebf95182c5551cc8260de4aeb85d5d090ef5a9e111ec87dc5ba0056db1194e", 16).unwrap();

    // Generate input vals
    let mut rng = rand::thread_rng();
    for _ in 0..num_inputs {
        //let a = BigUint::parse_bytes(b"264c5c24daa38c2acbbb92651c4540d6cae0cce1515b889a401baa0e4687915c", 16).unwrap();
        //let b = BigUint::parse_bytes(b"2f663889210ce842713e5cc30a485d50b07fff85fba23f7b7a8f43269ca6a5b8", 16).unwrap();
        //let a = &a * &r % &p;
        //let b = &b * &r % &p;

        //let a = (BigUint::from_bytes_be(&[2]) * &r) % &p;
        //let b = (BigUint::from_bytes_be(&[3]) * &r) % &p;
        
        //// Force a conditional subtraction
        //let a = BigUint::parse_bytes(b"2ea65ba9f05fdf3725993c9a96e3a5973b820daef8a2379d4ed50ef583c6a2a2", 16).unwrap();
        //let b = BigUint::parse_bytes(b"c2972aeac79b923460f3dc00ff4f7419e8e1f9b3e5ae5ee92c597a855caa750", 16).unwrap();

        let random_bytes = rng.gen::<[u8; 32]>();
        let a = BigUint::from_bytes_be(random_bytes.as_slice()) % &p;
        let random_bytes = rng.gen::<[u8; 32]>();
        let b = BigUint::from_bytes_be(random_bytes.as_slice()) % &p;

        a_vals.push(a.clone());
        b_vals.push(b.clone());
    }

    let mut expected: Vec<BigUint> = Vec::with_capacity(num_inputs);

    for i in 0..num_inputs {
        // ar * br * rinv
        let e = (&a_vals[i] * &b_vals[i] * &rinv) % &p;
        assert!(e < p);
        expected.push(e);
    }

    let mut input_as_bytes: Vec<Vec<u8>> = Vec::with_capacity(num_inputs);
    for i in 0..num_inputs {
        input_as_bytes.push(split_biguint(a_vals[i].clone()));
        input_as_bytes.push(split_biguint(b_vals[i].clone()));
    }

    let input_as_bytes: Vec<u8> = input_as_bytes.into_iter().flatten().collect();

    // Send to the GPU
    let result = pollster::block_on(single_buffer_compute("src/field_mul_mont.wgsl", &input_as_bytes, num_inputs)).unwrap();

    let chunks: Vec<Vec<u32>> = result
        .into_iter().chunks(16)
        .into_iter().map(|c| c.into_iter().collect())
        .collect();

    let results_as_biguint: Vec<BigUint> = chunks.iter().map(|c| limbs_to_bigint256(c)).collect();

    //let ar = &a_vals[0];
    //let br = &b_vals[0];
    //println!("a:   {:?}", hex::encode(a_vals[0].to_bytes_be()));
    //println!("b:   {:?}", hex::encode(b_vals[0].to_bytes_be()));
    //println!("ri:  {:?}", hex::encode(rinv.to_bytes_be()));
    //println!("abr: {:?}", hex::encode((ar * br * &rinv % &p).to_bytes_be()));
    //println!("");
    //println!("result: {:?}", hex::encode((results_as_biguint[0]).to_bytes_be()));

    //println!("{:?}", results_as_biguint);
    //println!("{:?}", expected);
    for i in 0..num_inputs {
        if results_as_biguint[i * 2] != expected[i] {
            println!("Error");
            println!("ar:   {:?}", hex::encode(a_vals[0].to_bytes_be()));
            println!("br:   {:?}", hex::encode(b_vals[0].to_bytes_be()));
        }
        assert_eq!(results_as_biguint[i * 2], expected[i]);
    }
}
