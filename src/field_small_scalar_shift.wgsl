struct BigInt256 {
    limbs: array<u32, 16>
}

struct BigInt272 {
    limbs: array<u32, 17>
}

@group(0)
@binding(0)
var<storage, read_write> buf: array<BigInt256>;

fn gen_p_medium() -> BigInt272 {
    var p: BigInt272;
    p.limbs[0] = 1u;
    p.limbs[2] = 12525u;
    p.limbs[3] = 39213u;
    p.limbs[4] = 63771u;
    p.limbs[5] = 2380u;
    p.limbs[6] = 39164u;
    p.limbs[7] = 8774u;
    p.limbs[15] = 16384u;
    return p;
}

// assumes a >= b
fn sub_272(a: ptr<function, BigInt272>, b: ptr<function, BigInt272>, res: ptr<function, BigInt272>) -> u32 {
    var W_mask = 65535u;
    var N = 16u;
    var borrow: u32 = 0u;
    for (var i: u32 = 0u; i < N + 1u; i = i + 1u) {
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

// This code is adapted from https://github.com/sampritipanda/msm-webgpu/blob/main/bigint.wgsl
@compute
@workgroup_size(1)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    var a: BigInt256 = buf[global_id.x];
    buf[global_id.x] = field_small_scalar_shift(2u, &a);
}
