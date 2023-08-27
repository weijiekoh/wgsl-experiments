use crate::gpu::single_buffer_compute;
use crate::utils::{bigints_to_bytes, u32s_to_bigints};
use num_bigint::BigUint;
use ark_bn254::{G1Projective, G1Affine};
use ark_bn254::fr::Fr;
use ark_ec::{CurveGroup, Group, VariableBaseMSM};
use std::ops::{Shr, Mul};
use num_traits::Zero;
use stopwatch::Stopwatch;
use std::ops::BitAnd;

pub fn naive_msm(points: &Vec<G1Projective>, scalars: &Vec<Fr>) -> G1Affine {
    assert!(points.len() > 0);
    assert!(points.len() == scalars.len());

    let mut acc = points[0].mul(scalars[0]);
    for i in 1..points.len() {
        acc += points[i].mul(scalars[i]);
    }
    acc.into_affine()
}

pub fn ark_msm(points: &Vec<G1Projective>, scalars: &Vec<Fr>) -> G1Affine {
    let affine_points: Vec<G1Affine> = points.iter().map(|x| x.into_affine()).collect();
    G1Projective::msm(&affine_points, scalars.as_slice()).unwrap().into_affine()
}

//pub fn pippenger_msm(points: &Vec<G1Projective>, scalars: &Vec<Fr>) -> G1Affine {
//}


pub fn fr_to_biguint(s: &Fr) -> BigUint {
    (*s).into()
}

#[test]
pub fn test_pippenger() {
    let num_points = 4;
    //let mut scalars = Vec::with_capacity(num_points);
    let scalars = vec![
        Fr::from(6u64),
        Fr::from(11u64),
        Fr::from(8u64),
        Fr::from(13u64),
    ];
    let mut points = Vec::with_capacity(num_points);
    let g = G1Projective::generator();

    for _ in 0..num_points {
        //let x = (i + 1) * 10;
        //scalars.push(Fr::from(x as u64));
        points.push(g.clone());
    }

    // Perform the MSM on CPU and do a sanity check
    let naive_result = naive_msm(&points, &scalars);
    let ark_msm_result = ark_msm(&points, &scalars);

    assert_eq!(naive_result, ark_msm_result);

    // Set the max scalar size to 15 (inclusive). This is 4 bits.
    let max_scalar_bits = 4;

    // Ensure that the scalars are within range
    let max = 2u32.pow(max_scalar_bits);
    for s in &scalars {
        let max_as_fr = Fr::from(max);
        assert!(s < &max_as_fr);
    }

    // The bitlength of each window
    let window_size_bits = 2;
    let num_windows = max_scalar_bits / window_size_bits;

    let mut buckets = Vec::with_capacity(num_points - 1);
    for _ in 0..num_points {
        buckets.push(Vec::with_capacity(num_points));
    }

    for i in 0..num_windows {
        let wi = i * window_size_bits;
        println!("Window: c_{}", i as u32 * wi);
        let mask = 2u32.pow((i as u32 + 1u32) * window_size_bits) - 1u32;
        let mask = BigUint::from(mask);

        for (si, s) in scalars.iter().enumerate() {
            let multiplier = 2u32.pow(wi);
            let window_val = fr_to_biguint(s)
                .bitand(&mask)
                .shr(i as u32 * window_size_bits);
            let window_val: usize = window_val.try_into().unwrap();
            println!(
                "si: {}, s: {}, window_val: {}, multiplier: {}",
                si,
                s,
                window_val,
                multiplier
            );

            if window_val > 0 {
                let bucket_index = window_val - 1;
                let point = points[si].mul(Fr::from(multiplier) * Fr::from(window_val as u32));
                buckets[bucket_index].push(point);
            }
        }
    }

    let mut sum = G1Projective::zero();
    for b in buckets {
        for p in b {
            sum += p;
        }
    }
    assert_eq!(sum, ark_msm_result);

    /*
    let mut inputs: Vec<BigUint> = Vec::with_capacity(3);
    inputs.push(x);
    inputs.push(y);
    inputs.push(z);
    inputs.push(x2);
    inputs.push(y2);
    inputs.push(z2);

    //println!("{:?}", inputs);
    let inputs = bigints_to_bytes(inputs);

    // Send to the GPU
    let sw = Stopwatch::start_new();
    let result = pollster::block_on(single_buffer_compute("src/jacobian_add.wgsl", &inputs, 1)).unwrap();
    println!("GPU took {}ms", sw.elapsed_ms());
    let result = u32s_to_bigints(result);
    //println!("{:?}", result);

    let xn = result[0].clone().into();
    let yn = result[1].clone().into();
    let zn = result[2].clone().into();

    let result = G1Projective::new(xn, yn, zn).into_affine();

    assert_eq!(result, ark_added_pt);
    */
}
