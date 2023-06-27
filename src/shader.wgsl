@group(0)
@binding(0)
var<storage, read_write> v_indices: array<u32>; // this is used as both input and output for convenience

// Return the nth Fibonacci number.
// 0, 1, 1, 2, 3, 5, 8...
fn fibonacci(n_fib: u32) -> u32{
    if (n_fib == 0u) {
        return 0u;
    }

    if (n_fib == 1u) {
        return 1u;
    }

    if (n_fib == 2u) {
        return 1u;
    }
    
    var a: u32 = 0u;
    var b: u32 = 1u;
    var c: u32 = 2u;
    var i: u32 = 1u;

    for (var i: u32 = 1u; i < n_fib; i ++) {
        c = a + b;

        var x = b;
        b = c;
        a = x;
    }

    return c;
}

@compute
@workgroup_size(1)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    v_indices[global_id.x] = fibonacci(v_indices[global_id.x]);
}
