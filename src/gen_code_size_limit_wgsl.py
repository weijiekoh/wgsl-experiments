template = """
struct BigInt256 {
    limbs: array<u32, 16>
}

@group(0)
@binding(0)
var<storage, read_write> input: array<BigInt256>;

<REPLACE>

@compute
@workgroup_size(1)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    input[global_id.x] = get_constant_0();
}
""".strip()

func_template = """
fn get_constant_{}() -> BigInt256 {{
    var p: BigInt256;
    p.limbs[0] = 4294967295u;
    p.limbs[1] = 4294967295u;
    p.limbs[2] = 4294967295u;
    p.limbs[3] = 4294967295u;
    p.limbs[4] = 4294967295u;
    p.limbs[5] = 4294967295u;
    p.limbs[6] = 4294967295u;
    p.limbs[7] = 4294967295u;
    p.limbs[8] = 4294967295u;
    p.limbs[9] = 4294967295u;
    p.limbs[10] = 4294967295u;
    p.limbs[11] = 4294967295u;
    p.limbs[12] = 4294967295u;
    p.limbs[13] = 4294967295u;
    p.limbs[14] = 4294967295u;
    p.limbs[15] = 4294967295u;
    return p;
}}
""".strip()

if __name__ == "__main__":
    functions = str()
    num_funcs = 1024
    for i in range(0, num_funcs):
        functions += func_template.format(str(i)) + "\n\n"

    code = template.replace("<REPLACE>", functions.strip())
    print(code)
