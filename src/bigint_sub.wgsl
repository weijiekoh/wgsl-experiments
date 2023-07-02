struct BigInt256 {
    limbs: array<u32, 16>
}

@group(0)
@binding(0)
var<storage, read_write> buf: array<BigInt256>; // this is used as both input and output for convenience

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

// This code is adapted from https://github.com/sampritipanda/msm-webgpu/blob/main/bigint.wgsl
@compute
@workgroup_size(1)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    for (var i: u32 = 0u; i < arrayLength(&buf) / 2u; i = i + 1u) {
        var a: BigInt256 = buf[global_id.x + (i * 2u)];
        var b: BigInt256 = buf[global_id.x + (i * 2u + 1u)];
        var c: BigInt256;
        sub(&a, &b, &c);
        buf[global_id.x + (i * 2u)] = c;
    }
}
