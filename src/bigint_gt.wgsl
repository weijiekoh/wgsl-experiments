struct BigInt256 {
    limbs: array<u32, 16>
}

@group(0)
@binding(0)
var<storage, read_write> buf: array<BigInt256>; // this is used as both input and output for convenience

// Returns a > b
fn gt(a: ptr<function, BigInt256>, b: ptr<function, BigInt256>) -> bool {
    var j: u32 = 0u;
    for (; j < 16u; j ++) {
        if ((*a).limbs[15u - j] > 0u || (*b).limbs[15u - j] > 0u) {
            break;
        }
    }

    for (; j < 16u; j ++) {
        if ((*a).limbs[15u - j] > (*b).limbs[15u - j]) {
            return true;
        } else {
            break;
        }
    }
    return false;
}

// This code is adapted from https://github.com/sampritipanda/msm-webgpu/blob/main/bigint.wgsl
@compute
@workgroup_size(4)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    var a: BigInt256 = buf[global_id.x];
    var b: BigInt256 = buf[global_id.x+ 1u];

    var c: bool = gt(&a, &b);
    var res: BigInt256;
    if (c) {
        res.limbs[0] = 1u;
    } else {
        res.limbs[0] = 0u;
    }

    buf[global_id.x] = res;
}
