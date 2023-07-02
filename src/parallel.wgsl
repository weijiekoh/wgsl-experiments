@group(0)
@binding(0)
var<storage, read_write> buf: array<u32>; // this is used as both input and output for convenience

const WG_SIZE: u32 = 4u;

@compute
@workgroup_size(256)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    var results: array<u32, WG_SIZE>;
    for (var i: u32 = 0u; i < WG_SIZE; i ++) {
        results[i] = buf[global_id.x + i];
    }

    for (var i: u32 = 0u; i < 256u; i ++) {
        for (var j: u32 = 0u; j < WG_SIZE; j ++) {
            results[j] = results[j] * results[j];
        }
    }

    for (var i: u32 = 0u; i < WG_SIZE; i ++) {
        buf[global_id.x + i] = results[i];
    }

/*
    var result: u32 = buf[global_id.x];
    var result2: u32 = buf[global_id.x + 1u];

    for (var i: u32 = 0u; i < arrayLength(&buf); i ++) {
        result = result * result;
        result2 = result2 * result2;
    }

    buf[global_id.x] = result;
    buf[global_id.x + 1u] = result2;
*/
}
