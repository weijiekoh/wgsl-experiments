struct BigInt256 {
    limbs: array<u32, 16> }

@group(0)
@binding(0)
var<storage, read_write> buf: array<BigInt256>;

fn sub(a: ptr<function,BigInt256>, b: ptr<function,BigInt256>, res: ptr<function, BigInt256>) -> u32 {
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

// Also assumes a >= b
fn field_sub(a: ptr<function, BigInt256>, b: ptr<function, BigInt256>) -> BigInt256 {
    var res: BigInt256;
    var carry = sub(a, b, &res);
    if (carry == 0u) {
        return res;
    }
    var p: BigInt256 = gen_p();
    return add(&res, &p);
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
    var b: BigInt256 = buf[global_id.x + 1u];
    buf[global_id.x] = field_sub(&a, &b);
}
