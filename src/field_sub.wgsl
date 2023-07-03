struct BigInt256 {
    limbs: array<u32, 16> }

@group(0)
@binding(0)
var<storage, read_write> buf: array<BigInt256>;

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

fn gen_p() -> BigInt256 {
    var p: BigInt256;
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

// This code is adapted from https://github.com/sampritipanda/msm-webgpu/blob/main/bigint.wgsl
@compute
@workgroup_size(8)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    var a: BigInt256 = buf[global_id.x];
    var b: BigInt256 = buf[global_id.x + 1u];
    buf[global_id.x] = field_sub(&a, &b);
}
