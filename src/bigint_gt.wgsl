struct BigInt256 {
    limbs: array<u32, 16>
}

@group(0)
@binding(0)
var<storage, read_write> buf: array<BigInt256>; // this is used as both input and output for convenience

// Returns 1 if a > b and 0 otherwise
fn gt(a: ptr<function, BigInt256>, b: ptr<function, BigInt256>) -> u32 {
    var j: u32 = 16u;
    for (; j > 0u; j --) {
        if ((*a).limbs[j] > 0u || (*b).limbs[j] > 0u) {
            break;
        }
    }

    for (; j > 0u; j --) {
        if ((*a).limbs[j] > (*b).limbs[j]) {
            return 1u;
        } else {
            break;
        }
    }
    return 0u;
}

// This code is adapted from https://github.com/sampritipanda/msm-webgpu/blob/main/bigint.wgsl
@compute
@workgroup_size(4)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    var a: BigInt256 = buf[global_id.x];
    var b: BigInt256 = buf[global_id.x+ 1u];

    var c: u32 = gt(&a, &b);
    var res: BigInt256;
    res.limbs[0] = c;

    buf[global_id.x] = res;
}
