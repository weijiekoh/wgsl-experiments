struct BigInt256 {
    limbs: array<u32, 16>
}

@group(0)
@binding(0)
var<storage, read_write> buf: array<BigInt256>; // this is used as both input and output for convenience

// Returns 1 if a == b and 0 otherwise
fn eq(a: ptr<function, BigInt256>, b: ptr<function, BigInt256>) -> u32 {
    for (var i: u32 = 0u; i < 16u; i ++) {
        if ((*a).limbs[i] != (*b).limbs[i]) {
            return 0u;
        }
    }
    return 1u;
}

// This code is adapted from https://github.com/sampritipanda/msm-webgpu/blob/main/bigint.wgsl
@compute
@workgroup_size(4)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    var a: BigInt256 = buf[global_id.x];
    var b: BigInt256 = buf[global_id.x+ 1u];

    var c: u32 = eq(&a, &b);
    var res: BigInt256;
    res.limbs[0] = c;

    buf[global_id.x] = res;
}
