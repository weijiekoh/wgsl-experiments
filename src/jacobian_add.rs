use crate::gpu::single_buffer_compute;
use crate::utils::{bigints_to_bytes, u32s_to_bigints};
use num_bigint::BigUint;
use ark_bn254::{G1Projective};
use ark_bn254::fr::Fr;
use ark_ec::Group;
use ark_ec::CurveGroup;
use std::ops::Mul;
use stopwatch::Stopwatch;

#[test]
pub fn test_jacobian_add() {
    let s = Fr::from(4);
    let pt = G1Projective::generator().mul(s);

    let s2 = Fr::from(5);
    let pt2 = G1Projective::generator().mul(s2);
    let ark_added_pt = (pt + pt2).into_affine();

    let x: BigUint = pt.x.into();
    let y: BigUint = pt.y.into();
    let z: BigUint = pt.z.into();
    let x2: BigUint = pt2.x.into();
    let y2: BigUint = pt2.y.into();
    let z2: BigUint = pt2.z.into();

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
}
