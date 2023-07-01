@group(0)
@binding(0)
var<storage, read_write> buf: array<u32>; // this is used as both input and output for convenience

@compute
@workgroup_size(1)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    var result: u32 = buf[global_id.x];

    for (var i: u32 = 0u; i < arrayLength(&buf); i ++) {
        result = result * result;
    }

    buf[global_id.x] = result;
}
