use crate::gpu::single_buffer_compute;
use crate::utils::{bigints_to_bytes, u32s_to_bigints};
use num_bigint::BigUint;
use num_traits::Num;
use ark_bn254::{G1Projective};
use ark_bn254::fr::Fr;
use ark_ec::Group;
use ark_ec::CurveGroup;
use std::ops::Mul;

pub fn field_sqr(a: &BigUint, q: &BigUint) -> BigUint {
    (a * a) % q
}

pub fn field_add(a: &BigUint, b: &BigUint, q: &BigUint) -> BigUint {
    (a + b) % q
}

pub fn field_mul(a: &BigUint, b: &BigUint, q: &BigUint) -> BigUint {
    (a * b) % q
}

pub fn field_sub(a: &BigUint, b: &BigUint, q: &BigUint) -> BigUint {
    if a >= b {
        a - b
    } else {
        q - (b - a)
    }
}

pub fn field_small_scalar_shift(s: u32, b: &BigUint, q: &BigUint) -> BigUint {
    let x: u64 = 2u64.pow(s).try_into().unwrap();
    let shift = BigUint::from(x);
    (shift * b) % q
}


pub fn jacobian_dbl(pt: G1Projective) -> G1Projective {
    let q = BigUint::from_str_radix("21888242871839275222246405745257275088696311157297823662689037894645226208583", 10).unwrap();

    let p = q.clone();

    let x: BigUint = pt.x.into();
    let y: BigUint = pt.y.into();
    let z: BigUint = pt.z.into();

    //println!("x: {}", x);
    //println!("y: {}", y);
    //println!("z: {}\n", z);

    let a = field_sqr(&x, &p);
    let b = field_sqr(&y, &p);
    let c = field_sqr(&b, &p);

    let x1_plus_b = field_add(&x, &b, &p);
    let a_c = field_add(&a, &c, &p);
    let x2 = field_sqr(&x1_plus_b, &p);
    let s = field_sub(&x2, &a_c, &p);

    let d = field_small_scalar_shift(1, &s, &p);
    let a_shifted = field_small_scalar_shift(1, &a, &p);
    let e = field_add(&a_shifted, &a, &p);
    let f = field_sqr(&e, &p);
    let d_shifted = field_small_scalar_shift(1, &d, &p);
    let x3 = field_sub(&f, &d_shifted, &p);
    let c_shifted = field_small_scalar_shift(3, &c, &p);
    let d_x3 = field_sub(&d, &x3, &p);
    let m = field_mul(&e, &d_x3, &p);
    let y3 = field_sub(&m, &c_shifted, &p);

    let y_shifted = field_small_scalar_shift(1, &y, &p);
    let z3 = field_mul(&y_shifted, &z, &p);

    //println!("x3: {}\ny3: {}\nz3: {}\n", x3, y3, z3);

    return G1Projective::new(x3.into(), y3.into(), z3.into());
}

#[test]
pub fn test_jacobian_dbl() {
    let s = Fr::from(4);
    let pt = G1Projective::generator().mul(s);
    let ark_doubled_pt = (pt + pt).into_affine();

    let doubled_pt = jacobian_dbl(pt).into_affine();
    assert_eq!(doubled_pt, ark_doubled_pt);

    let x: BigUint = pt.x.into();
    let y: BigUint = pt.y.into();
    let z: BigUint = pt.z.into();

    let mut inputs: Vec<BigUint> = Vec::with_capacity(3);
    inputs.push(x);
    inputs.push(y);
    inputs.push(z);

    let inputs = bigints_to_bytes(inputs);
    // Send to the GPU
    let result = pollster::block_on(single_buffer_compute("src/jacobian_dbl.wgsl", &inputs, 1)).unwrap();
    let result = u32s_to_bigints(result);

    let xn = result[0].clone().into();
    let yn = result[1].clone().into();
    let zn = result[2].clone().into();

    let result = G1Projective::new(xn, yn, zn).into_affine();

    assert_eq!(result, ark_doubled_pt);
}
