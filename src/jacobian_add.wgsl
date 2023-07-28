struct BigInt256 {
    limbs: array<u32, 16>
}

struct BigInt272 {
    limbs: array<u32, 17>
}

struct BigInt512 {
    limbs: array<u32, 32>
}

struct JacobianPoint {
    x: BigInt256,
    y: BigInt256,
    z: BigInt256
};

@group(0)
@binding(0)
var<storage, read_write> buf: array<JacobianPoint>;

// p = base field modulus
fn gen_p() -> BigInt256 {
    var p: BigInt256;
    p.limbs[0] = 0xfd47u;
    p.limbs[1] = 0xd87cu;
    p.limbs[2] = 0x8c16u;
    p.limbs[3] = 0x3c20u;
    p.limbs[4] = 0xca8du;
    p.limbs[5] = 0x6871u;
    p.limbs[6] = 0x6a91u;
    p.limbs[7] = 0x9781u;
    p.limbs[8] = 0x585du;
    p.limbs[9] = 0x8181u;
    p.limbs[10] = 0x45b6u;
    p.limbs[11] = 0xb850u;
    p.limbs[12] = 0xa029u;
    p.limbs[13] = 0xe131u;
    p.limbs[14] = 0x4e72u;
    p.limbs[15] = 0x3064u;
    return p;
}

fn gen_p_medium() -> BigInt272 {
    var p: BigInt272;
    p.limbs[0] = 0xfd47u;
    p.limbs[1] = 0xd87cu;
    p.limbs[2] = 0x8c16u;
    p.limbs[3] = 0x3c20u;
    p.limbs[4] = 0xca8du;
    p.limbs[5] = 0x6871u;
    p.limbs[6] = 0x6a91u;
    p.limbs[7] = 0x9781u;
    p.limbs[8] = 0x585du;
    p.limbs[9] = 0x8181u;
    p.limbs[10] = 0x45b6u;
    p.limbs[11] = 0xb850u;
    p.limbs[12] = 0xa029u;
    p.limbs[13] = 0xe131u;
    p.limbs[14] = 0x4e72u;
    p.limbs[15] = 0x3064u;
    return p;
}

fn gen_p_wide() -> BigInt512 {
    var p: BigInt512;
    p.limbs[0] = 0xfd47u;
    p.limbs[1] = 0xd87cu;
    p.limbs[2] = 0x8c16u;
    p.limbs[3] = 0x3c20u;
    p.limbs[4] = 0xca8du;
    p.limbs[5] = 0x6871u;
    p.limbs[6] = 0x6a91u;
    p.limbs[7] = 0x9781u;
    p.limbs[8] = 0x585du;
    p.limbs[9] = 0x8181u;
    p.limbs[10] = 0x45b6u;
    p.limbs[11] = 0xb850u;
    p.limbs[12] = 0xa029u;
    p.limbs[13] = 0xe131u;
    p.limbs[14] = 0x4e72u;
    p.limbs[15] = 0x3064u;
    return p;
}

fn gen_base_m() -> BigInt256 {
    var p: BigInt256;
    p.limbs[0] = 0x90e5u;
    p.limbs[1] = 0x19bfu;
    p.limbs[2] = 0xed8au;
    p.limbs[3] = 0x6f3au;
    p.limbs[4] = 0x4c08u;
    p.limbs[5] = 0x67cdu;
    p.limbs[6] = 0x5e17u;
    p.limbs[7] = 0xae96u;
    p.limbs[8] = 0x3013u;
    p.limbs[9] = 0x6807u;
    p.limbs[10] = 0x4a58u;
    p.limbs[11] = 0xab07u;
    p.limbs[12] = 0x04a7u;
    p.limbs[13] = 0x623au;
    p.limbs[14] = 0x7462u;
    p.limbs[15] = 0x54a4u;
    return p;
}

// assumes a >= b
fn sub_272(a: ptr<function, BigInt272>, b: ptr<function, BigInt272>, res: ptr<function, BigInt272>) -> u32 {
    var W_mask = 65535u;
    var borrow: u32 = 0u;
    for (var i: u32 = 0u; i < 17u; i = i + 1u) {
        (*res).limbs[i] = (*a).limbs[i] - (*b).limbs[i] - borrow;
        if ((*a).limbs[i] < ((*b).limbs[i] + borrow)) {
            (*res).limbs[i] += W_mask + 1u;
            borrow = 1u;
        } else {
            borrow = 0u;
        }
    }
    return borrow;
}

fn shorten(a: ptr<function, BigInt272>) -> BigInt256 {
    var out: BigInt256;
    for (var i = 0u; i < 16u; i = i + 1u) {
        out.limbs[i] = (*a).limbs[i];
    }
    return out;
}

// reduces l times (assumes that 0 <= a < multi * mod)
fn field_reduce_272(a: ptr<function, BigInt272>, multi: u32) -> BigInt256 {
    var res: BigInt272;
    var cur = *a;
    var cur_multi = multi + 1u;
    var p_medium = gen_p_medium();
    while (cur_multi > 0u) {
        var underflow = sub_272(&cur, &p_medium, &res);
        if (underflow == 1u) {
            return shorten(&cur);
        } else {
            cur = res;
        }
        cur_multi = cur_multi - 1u;
    }
    var zero: BigInt256;
    return zero;
}

/// Shift the input Bigint256 left by l. i.e. a shift by l is a multiplied by 2
//** l. Assumes that l is less than 16.
fn field_small_scalar_shift(l: u32, a: ptr<function, BigInt256>) -> BigInt256 {
    var res: BigInt272;
    for (var i = 0u; i < 16u; i = i + 1u) {
        let shift = (*a).limbs[i] << l;
        res.limbs[i] = res.limbs[i] | (shift & 65535u);
        res.limbs[i + 1u] = (shift >> 16u);
    }

    var output = field_reduce_272(&res, (1u << l)); // can probably be optimised
    return output;
}

fn mul(a: ptr<function, BigInt256>, b: ptr<function, BigInt256>) -> BigInt512 {
    var N = 16u;
    var W = 16u;
    var W_mask = 65535u;
    var res: BigInt512;
    for (var i = 0u; i < N; i = i + 1u) {
        for (var j = 0u; j < N; j = j + 1u) {
            let c = (*a).limbs[i] * (*b).limbs[j];
            res.limbs[i+j] += c & W_mask;
            res.limbs[i+j+1u] += c >> W;
        }   
    }
    // start from 0 and carry the extra over to the next index
    for (var i = 0u; i < 2u*N - 1u; i = i + 1u) {
        res.limbs[i+1u] += res.limbs[i] >> W;
        res.limbs[i] = res.limbs[i] & W_mask;
    }
    return res;
}

fn get_higher_with_slack(a: ptr<function, BigInt512>) -> BigInt256 {
    var out: BigInt256;
    var slack = 2u;
    var W = 16u;
    var W_mask = 65535u;
    for (var i = 0u; i < 16u; i ++) {
        /*
          slack = 1
          W - slack = 15

          This loop operates on the most significant bits of the bigint.
          It discards the least significant bits.
        */ 
        //                       mul by 2 ** 1         divide by 2 ** 15
        out.limbs[i] = (((*a).limbs[i + 16u] << slack) + ((*a).limbs[i + 15u] >> (W - slack))) & W_mask;
    }
    return out;
}

fn field_mul(a: ptr<function, BigInt256>, b: ptr<function, BigInt256>) -> BigInt256 {
    var bm = gen_base_m();
    var p = gen_p();
    var p_wide = gen_p_wide();

    var xy: BigInt512 = mul(a, b);
    var xy_hi: BigInt256 = get_higher_with_slack(&xy);
    var l: BigInt512 = mul(&xy_hi, &bm);
    var l_hi: BigInt256 = get_higher_with_slack(&l);
    var lp: BigInt512 = mul(&l_hi, &p);
    var r_wide: BigInt512;
    sub_512(&xy, &lp, &r_wide);

    var r_wide_reduced: BigInt512;
    var underflow = sub_512(&r_wide, &p_wide, &r_wide_reduced);
    if (underflow == 0u) {
        r_wide = r_wide_reduced;
    }
    var r: BigInt256;
    for (var i = 0u; i < 16u; i ++) {
        r.limbs[i] = r_wide.limbs[i];
    }
    return field_reduce(&r);
}

fn field_sqr(a: ptr<function, BigInt256>) -> BigInt256 {
    return field_mul(a, a);
}

fn sub_b(a: ptr<function, BigInt256>, b: ptr<function, BigInt256>, res: ptr<function, BigInt256>) -> u32 {
    var borrow: u32 = 0u;
    for (var i: u32 = 0u; i < 16u; i = i + 1u) {
        (*res).limbs[i] = (*a).limbs[i] - (*b).limbs[i] - borrow;
        if ((*a).limbs[i] < ((*b).limbs[i] + borrow)) {
            (*res).limbs[i] += 65536u;
            borrow = 1u;
        } else {
            borrow = 0u;
        }
    }
    return borrow;
}

fn sub(a: ptr<function, BigInt256>, b: ptr<function, BigInt256>) -> BigInt256 {
    var res: BigInt256;
    var borrow: u32 = 0u;
    for (var i: u32 = 0u; i < 16u; i ++) {
        res.limbs[i] = (*a).limbs[i] - (*b).limbs[i] - borrow;
        if ((*a).limbs[i] < ((*b).limbs[i] + borrow)) {
            res.limbs[i] += 65536u;
            borrow = 1u;
        } else {
            borrow = 0u;
        }
    }
    return res;
}

// a < b  --> 0
// a == b --> 1
// a > b  --> 2
fn cmp(a: ptr<function, BigInt256>, b: ptr<function, BigInt256>) -> u32 {
    var res = 0u;
    var j: u32 = 0u;
    for (; j < 16u; j ++) {
        var i = 15u - j;
        if ((*a).limbs[i] != 0u || (*b).limbs[i] != 0u) {
            break;
        }
    }

    for (; j < 16u; j ++) {
        var i = 15u - j;
        if ((*a).limbs[i] > (*b).limbs[i]) {
            return 2u;
        } else if ((*a).limbs[i] < (*b).limbs[i]) {
            return 0u;
        }
    }
    return 1u;
}

// Also assumes a >= b
fn field_sub(a: ptr<function, BigInt256>, b: ptr<function, BigInt256>) -> BigInt256 {
    var c = cmp(a, b);
    if (c == 0u) {
        var r: BigInt256 = sub(b, a);
        var p = gen_p();
        return sub(&p, &r);
    } else if (c == 1u) {
        var r: BigInt256;
        return r;
    }
    return sub(a, b);
}

// assumes a >= b
fn sub_512(a: ptr<function, BigInt512>, b: ptr<function, BigInt512>, res: ptr<function, BigInt512>) -> u32 {
    var W_mask = 65535u;

    var borrow: u32 = 0u;
    for (var i: u32 = 0u; i < 32u; i = i + 1u) {
        (*res).limbs[i] = (*a).limbs[i] - (*b).limbs[i] - borrow;
        if ((*a).limbs[i] < ((*b).limbs[i] + borrow)) {
            (*res).limbs[i] += W_mask + 1u;
            borrow = 1u;
        } else {
            borrow = 0u;
        }
    }
    return borrow;
}

/*// once reduces once (assumes that 0 <= a < 2 * mod)*/
fn field_reduce(a: ptr<function, BigInt256>) -> BigInt256 {
    var res: BigInt256;
    var p: BigInt256 = gen_p();
    var underflow = sub_b(a, &p, &res);
    if (underflow == 1u) {
        return *a;
    }

    return res;
}

fn add(a: ptr<function, BigInt256>, b: ptr<function, BigInt256>) -> BigInt256 {
    // Stores the result and its limbs should be initialised to 0
    var res: BigInt256;

    var carry: u32 = 0u;
    for (var j: u32 = 0u; j < 16u; j = j + 1u) {
        let c: u32 = (*a).limbs[j] + (*b).limbs[j] + carry;
        res.limbs[j] = c & 65535u;
        carry = c >> 16u;
    }
    return res;
}

fn field_add(a: ptr<function, BigInt256>, b: ptr<function, BigInt256>) -> BigInt256 {
    var res: BigInt256 = add(a, b);
    return field_reduce(&res);
}

fn field_eq(a: ptr<function, BigInt256>, b: ptr<function, BigInt256>) -> bool {
    for (var i = 0u; i < 16u; i = i + 1u) {
        if ((*a).limbs[i] != (*b).limbs[i]) {
            return false;
        }
    }
    return true;
}

fn jacobian_dbl(p: JacobianPoint) -> JacobianPoint {
    // https://www.hyperelliptic.org/EFD/g1p/auto-shortw-jacobian-0.html#doubling-dbl-2009-l
    var x = p.x;
    var y = p.y;
    var z = p.z;

    var A = field_sqr(&x);
    var B = field_sqr(&y);
    var C = field_sqr(&B);
    var X1plusB = field_add(&x, &B);
    var A_C = field_add(&A, &C);
    var x2 = field_sqr(&X1plusB);
    var s = field_sub(&x2, &A_C);
    var D = field_small_scalar_shift(1u, &s);
    var A_shifted = field_small_scalar_shift(1u, &A);
    var E = field_add(&A_shifted, &A);
    var F = field_sqr(&E);
    var D_shifted = field_small_scalar_shift(1u, &D);
    var x3 = field_sub(&F, &D_shifted);
    var C_shifted = field_small_scalar_shift(3u, &C);
    var D_x3 = field_sub(&D, &x3);
    var m = field_mul(&E, &D_x3);
    var y3 = field_sub(&m, &C_shifted);

    var y_shifted = field_small_scalar_shift(1u, &y);
    var z3 = field_mul(&y_shifted, &z);

    return JacobianPoint(x3, y3, z3);
}

fn jacobian_add(p: JacobianPoint, q: JacobianPoint) -> JacobianPoint {
    // https://www.hyperelliptic.org/EFD/g1p/auto-shortw-jacobian-0.html#doubling-dbl-2009-l
    var px = p.x;
    var py = p.y;
    var pz = p.z;

    var qx = q.x;
    var qy = q.y;
    var qz = q.z;

    var zero: BigInt256;

    // https://www.hyperelliptic.org/EFD/g1p/auto-shortw-jacobian-0.html#addition-add-2007-bl
    if (field_eq(&py, &zero)) {
        return q;
    }
    if (field_eq(&qy, &zero)) {
        return p;
    }

    var Z1Z1 = field_sqr(&pz);
    var Z2Z2 = field_sqr(&qz);
    var U1 = field_mul(&px, &Z2Z2);
    var U2 = field_mul(&qx, &Z1Z1);

    var z2z2qz = field_mul(&Z2Z2, &qz);
    var z1z1pz = field_mul(&Z1Z1, &pz);
    var S1 = field_mul(&py, &z2z2qz);
    var S2 = field_mul(&qy, &z1z1pz);
    if (field_eq(&U1, &U2)) {
        if (field_eq(&S1, &S2)) {
            return jacobian_dbl(p);
        } else {
            var one: BigInt256;
            one.limbs[0] = 1u;
            return JacobianPoint(zero, zero, one);
        }
    }

    var H = field_sub(&U2, &U1);
    var H_sqr = field_sqr(&H);
    var I = field_small_scalar_shift(2u, &H_sqr);
    var J = field_mul(&H, &I);

    var S2_S1 = field_sub(&S2, &S1);
    var R = field_small_scalar_shift(1u, &S2_S1);
    var V = field_mul(&U1, &I);

    var R_sqr = field_sqr(&R);
    var V_shifted = field_small_scalar_shift(1u, &V);
    var J_V_shifted = field_add(&J, &V_shifted);
    var nx = field_sub(&R_sqr, &J_V_shifted);

    var S1_J = field_mul(&S1, &J);
    var S1_J_shifted = field_small_scalar_shift(1u, &S1_J);
    var V_nx = field_sub(&V, &nx);
    var R_V_nx = field_mul(&R, &V_nx);
    var ny = field_sub(&R_V_nx, &S1_J_shifted);

    var Z1Z1_Z2Z2 = field_add(&Z1Z1, &Z2Z2);
    var pz_qz = field_add(&pz, &qz);
    /*var pz_qz_pow = field_pow(&pz_qz, 2u);*/
    var pz_qz_pow = field_sqr(&pz_qz);
    var pz_qz_pow_Z1Z1_Z2Z2 = field_sub(&pz_qz_pow, &Z1Z1_Z2Z2);
    var nz = field_mul(&H, &pz_qz_pow_Z1Z1_Z2Z2);
    return JacobianPoint(nx, ny, nz);
}

// This code is adapted from https://github.com/sampritipanda/msm-webgpu/blob/main/bigint.wgsl
@compute
@workgroup_size(64)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    var a: JacobianPoint = buf[global_id.x];
    var b: JacobianPoint = buf[global_id.x + 1u];
    buf[global_id.x] = jacobian_add(a, b);
}
