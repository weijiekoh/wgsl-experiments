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

// This code is adapted from https://github.com/sampritipanda/msm-webgpu/blob/main/bigint.wgsl
@compute
@workgroup_size(64)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    var a: JacobianPoint = buf[global_id.x];
    buf[global_id.x] = jacobian_dbl(a);
}
