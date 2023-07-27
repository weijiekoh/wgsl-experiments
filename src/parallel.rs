use crate::gpu::single_buffer_compute;
use stopwatch::Stopwatch;
use std::num::Wrapping;
use rand::Rng;

pub fn operation(val: u32) -> u32 {
    let mut result = Wrapping(val);
    for _ in 0..65535 {
        result = result * result * result + Wrapping(3);
    }
    result.0
}

#[test]
pub fn test_parallel() {
    //let num_inputs = 2u32.pow(16) as usize;
    let num_inputs = 256;
    println!("Performing 65536 iterations of (x^3 + 3) on {} input values.", num_inputs);
  
    let mut rng = rand::thread_rng();
    let mut inputs: Vec<u32> = Vec::with_capacity(num_inputs);
    for _ in 0..num_inputs {
        inputs.push(rng.gen::<u32>() as u32);
    }

    // Compute the operations serially using the CPU
    let mut cpu_result = Vec::with_capacity(num_inputs);

    let sw = Stopwatch::start_new();
    for input in &inputs {
        cpu_result.push(operation(*input as u32));
    }
    println!("CPU took {}ms", sw.elapsed_ms());

    // Construct the input bytes as a flattened vec
    let mut input_as_bytes: Vec<Vec<u8>> = Vec::with_capacity(num_inputs);
    for i in 0..num_inputs {
        let bytes: Vec<u8> = bytemuck::cast_slice(&[inputs[i] as u32]).to_vec();
        input_as_bytes.push(bytes);
    }
    let input_as_bytes: Vec<u8> = input_as_bytes.into_iter().flatten().collect();

    // Perform the computations on GPU
    let sw = Stopwatch::start_new();
    let result = pollster::block_on(single_buffer_compute("src/parallel.wgsl", &input_as_bytes, 4)).unwrap();
    println!("GPU took {}ms", sw.elapsed_ms());

    // Convert the result
    let result: Vec<u32> = bytemuck::cast_slice(&result).to_vec();
    //println!("input: {:?}", inputs);
    //println!("cpu:   {:?}", cpu_result);
    //println!("gpu:   {:?}", result);
    
    // Check each result
    for i in 0..num_inputs {
        assert_eq!(cpu_result[i], result[i]);
    }
}
