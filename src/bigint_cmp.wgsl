// This code is adapted from https://github.com/sampritipanda/msm-webgpu/blob/main/bigint.wgsl
struct BigInt256 {
    limbs: array<u32, 16>
}

@group(0)
@binding(0)
var<storage, read_write> buf: array<BigInt256>; // this is used as both input and output for convenience

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

@compute
@workgroup_size(8)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    var a: BigInt256 = buf[global_id.x];
    var b: BigInt256 = buf[global_id.x+ 1u];

    var c: u32 = cmp(&a, &b);
    var res: BigInt256;
    res.limbs[0] = c;

    buf[global_id.x] = res;
}
