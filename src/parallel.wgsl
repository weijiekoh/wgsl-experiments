@group(0) @binding(0)
var<storage, read_write> buf: array<u32>; // this is used as both input and output for convenience

fn operation(val: u32) -> u32 {
    var result: u32 = val;
    for (var i: u32 = 0u; i < 65535u; i ++) {
        result = result * result * result + 3u;
    }
    return result;
}

@compute @workgroup_size(64)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    buf[global_id.x] = operation(buf[global_id.x]);
}
