struct BigInt256 {
    limbs: array<u32, 16>
}

@group(0)
@binding(0)
var<storage, read_write> buf: array<BigInt256>; // this is used as both input and output for convenience

// This code is adapted from https://github.com/sampritipanda/msm-webgpu/blob/main/bigint.wgsl
fn double(val: BigInt256) -> BigInt256 {
    // Stores the result and its limbs should be initialised to 0
    var res: BigInt256;

    // res = val + val
    var a: BigInt256 = val;
    var b: BigInt256 = val;

    var carry: u32 = 0u;
    for (var i: i32 = 0; i < 16; i = i + 1) {
        let c: u32 = a.limbs[i] + b.limbs[i] + carry;
        res.limbs[i] = c & 65535u;
        carry = c >> 16u;
    }
    return res;
}

@compute
@workgroup_size(256)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    buf[global_id.x] = double(buf[global_id.x]);
}
