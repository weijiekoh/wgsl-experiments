struct BigInt256 {
    limbs: array<u32, 16>
}

@group(0)
@binding(0)
var<storage, read_write> buf: array<BigInt256>; // this is used as both input and output for convenience

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

// This code is adapted from https://github.com/sampritipanda/msm-webgpu/blob/main/bigint.wgsl
@compute
@workgroup_size(1)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    for (var i: u32 = 0u; i < arrayLength(&buf) / 2u; i = i + 1u) {
        var a: BigInt256 = buf[global_id.x + (i * 2u)];
        var b: BigInt256 = buf[global_id.x + (i * 2u + 1u)];
        var c: BigInt256 = add(&a, &b);
        buf[global_id.x + (i * 2u)] = c;
    }
}
