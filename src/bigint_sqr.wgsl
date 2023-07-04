struct BigInt256 {
    limbs: array<u32, 16>
}

struct BigInt512 {
    limbs: array<u32, 32>
}

@group(0)
@binding(0)
var<storage, read_write> input: array<BigInt256>;

@group(0)
@binding(1)
var<storage, read_write> output: array<BigInt512>;

// This code is adapted from https://github.com/sampritipanda/msm-webgpu/blob/main/bigint.wgsl
fn sqr(a: ptr<function, BigInt256>) -> BigInt512 {
    var res: BigInt512;

    var N = 16u;
    var W = 16u;
    var W_mask = 65535u;

    for (var i = 0u;i < N; i = i + 1u) {
        let sc = (*a).limbs[i] * (*a).limbs[i];
        res.limbs[(i << 1u)] += sc & W_mask;
        res.limbs[(i << 1u)+1u] += sc >> W;

        for (var j = i + 1u; j < N; j = j + 1u) {
            let c = (*a).limbs[i] * (*a).limbs[j];
            res.limbs[i+j] += (c & W_mask) << 1u;
            res.limbs[i+j+1u] += (c >> W) << 1u;
        }
    }

    for (var i = 0u; i < 2u * N - 1u; i = i + 1u) {
        res.limbs[i+1u] += res.limbs[i] >> W;
        res.limbs[i] = res.limbs[i] & W_mask;
    }

    return res;
}

@compute
@workgroup_size(2)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    var val: BigInt256 = input[global_id.x];
    output[global_id.x] = sqr(&val);
}
