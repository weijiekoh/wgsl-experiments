struct BigInt256 {
    limbs: array<u32, 16>
}

struct BigInt512 {
    limbs: array<u32, 32>
}

@group(0)
@binding(0)
var<storage, read_write> buf: array<BigInt256>;

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
          This loop operates on the most significant bits of the bigint.
          It discards the least significant bits.
        */ 
        //                       mul by 2 ** 1         divide by 2 ** 15
        out.limbs[i] = (((*a).limbs[i + 16u] << slack) + ((*a).limbs[i + 15u] >> (W - slack))) & W_mask;
    }
    return out;
}

fn field_mul(a: ptr<function, BigInt256>, b: ptr<function, BigInt256>) -> BigInt256 {
    var N = 16u;
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
    for (var i = 0u; i < N; i ++) {
        r.limbs[i] = r_wide.limbs[i];
    }
    return field_reduce(&r);
}

fn field_sqr(a: ptr<function, BigInt256>) -> BigInt256 {
    return field_mul(a, a);
}

fn sub(a: ptr<function, BigInt256>, b: ptr<function, BigInt256>, res: ptr<function, BigInt256>) -> u32 {
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

// assumes a >= b
fn sub_512(a: ptr<function, BigInt512>, b: ptr<function, BigInt512>, res: ptr<function, BigInt512>) -> u32 {
    var W_mask = 65535u;
    var N = 16u;

    var borrow: u32 = 0u;
    for (var i: u32 = 0u; i < (2u*N); i = i + 1u) {
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

fn gen_p() -> BigInt256 {
    var p: BigInt256;
    p.limbs[0] = 1u;
    p.limbs[1] = 61440u;
    p.limbs[2] = 62867u;
    p.limbs[3] = 17377u;
    p.limbs[4] = 28817u;
    p.limbs[5] = 31161u;
    p.limbs[6] = 59464u;
    p.limbs[7] = 10291u;
    p.limbs[8] = 22621u;
    p.limbs[9] = 33153u;
    p.limbs[10] = 17846u;
    p.limbs[11] = 47184u;
    p.limbs[12] = 41001u;
    p.limbs[13] = 57649u;
    p.limbs[14] = 20082u;
    p.limbs[15] = 12388u;

    return p;
}

fn gen_base_m() -> BigInt256 {
    var p: BigInt256;
    p.limbs[0] = 59685u;
    p.limbs[1] = 48669u;
    p.limbs[2] = 934u;
    p.limbs[3] = 25095u;
    p.limbs[4] = 32942u;
    p.limbs[5] = 2536u;
    p.limbs[6] = 34080u;
    p.limbs[7] = 28996u;
    p.limbs[8] = 12308u;
    p.limbs[9] = 26631u;
    p.limbs[10] = 19032u;
    p.limbs[11] = 43783u;
    p.limbs[12] = 1191u;
    p.limbs[13] = 25146u;
    p.limbs[14] = 29794u;
    p.limbs[15] = 21668u;

    return p;
}

fn gen_p_wide() -> BigInt512 {
    var p: BigInt512;
    p.limbs[0] = 1u;
    p.limbs[1] = 61440u;
    p.limbs[2] = 62867u;
    p.limbs[3] = 17377u;
    p.limbs[4] = 28817u;
    p.limbs[5] = 31161u;
    p.limbs[6] = 59464u;
    p.limbs[7] = 10291u;
    p.limbs[8] = 22621u;
    p.limbs[9] = 33153u;
    p.limbs[10] = 17846u;
    p.limbs[11] = 47184u;
    p.limbs[12] = 41001u;
    p.limbs[13] = 57649u;
    p.limbs[14] = 20082u;
    p.limbs[15] = 12388u;
    p.limbs[16] = 0u;
    p.limbs[17] = 0u;
    p.limbs[18] = 0u;
    p.limbs[19] = 0u;
    p.limbs[20] = 0u;
    p.limbs[21] = 0u;
    p.limbs[22] = 0u;
    p.limbs[23] = 0u;
    p.limbs[24] = 0u;
    p.limbs[25] = 0u;
    p.limbs[26] = 0u;
    p.limbs[27] = 0u;
    p.limbs[28] = 0u;
    p.limbs[29] = 0u;
    p.limbs[30] = 0u;
    p.limbs[31] = 0u;
    return p;
}

/*// once reduces once (assumes that 0 <= a < 2 * mod)*/
fn field_reduce(a: ptr<function, BigInt256>) -> BigInt256 {
    var res: BigInt256;
    var p: BigInt256 = gen_p();
    var underflow = sub(a, &p, &res);
    if (underflow == 1u) {
        return *a;
    }

    return res;
}

// This code is adapted from https://github.com/sampritipanda/msm-webgpu/blob/main/bigint.wgsl
@compute
@workgroup_size(1)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    var a: BigInt256 = buf[global_id.x];
    buf[global_id.x] = field_sqr(&a);
}
