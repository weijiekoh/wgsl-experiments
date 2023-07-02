@group(0)
@binding(0)
var<storage, read_write> buf: array<u32>; // this is used as both input and output for convenience

@compute
@workgroup_size(32)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    var result: u32 = buf[global_id.x];

    for (var i: u32 = 0u; i < 1048576u; i++) {
        result = result * result + 3u;
    }

    buf[global_id.x] = result;

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
