use wgpu::util::DeviceExt;
use crate::gpu::device_setup_default;
use stopwatch::Stopwatch;
use std::num::Wrapping;
use rand::Rng;

async fn parallel(input_bytes: Vec<u8>) -> Option<Vec<u8>> {
    let (_, _, device, queue, compute_pipeline, mut encoder) = device_setup_default("src/parallel.wgsl").await;
    let num_inputs = input_bytes.len() / 4;

    // Gets the size in bytes of the buffer.
    let slice_size = num_inputs * std::mem::size_of::<u32>();
    let size = slice_size as wgpu::BufferAddress;

    // Instantiates buffer without data.
    // `usage` of buffer specifies how it can be used:
    //   `BufferUsages::MAP_READ` allows it to be read (outside the shader).
    //   `BufferUsages::COPY_DST` allows it to be the destination of the copy.
    let staging_buffer = device.create_buffer(&wgpu::BufferDescriptor {
        label: None,
        size,
        usage: wgpu::BufferUsages::MAP_READ | wgpu::BufferUsages::COPY_DST,
        mapped_at_creation: false,
    });

    // Instantiates buffer with data.
    // Usage allowing the buffer to be:
    //   A storage buffer (can be bound within a bind group and thus available to a shader).
    //   The destination of a copy.
    //   The source of a copy.
    let storage_buffer = device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
        label: Some("Storage Buffer"),
        contents: &input_bytes,
        usage: wgpu::BufferUsages::STORAGE
            | wgpu::BufferUsages::COPY_DST
            | wgpu::BufferUsages::COPY_SRC,
    });

    // Instantiates the bind group, once again specifying the binding of buffers.
    let bind_group_layout = compute_pipeline.get_bind_group_layout(0);
    let bind_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
        label: None,
        layout: &bind_group_layout,
        entries: &[wgpu::BindGroupEntry {
            binding: 0,
            resource: storage_buffer.as_entire_binding(),
        }],
    });

    {
        let mut cpass = encoder.begin_compute_pass(&wgpu::ComputePassDescriptor { label: None });
        cpass.set_pipeline(&compute_pipeline);
        cpass.set_bind_group(0, &bind_group, &[]);
        cpass.insert_debug_marker("debug marker");
        //cpass.dispatch_workgroups(num_inputs as u32 / 2u32, 1, 1); // Number of cells to run, the (x,y,z) size of item being processed
        let num_workgroups_x = 2;
        cpass.dispatch_workgroups(num_workgroups_x as u32, 1, 1); // Number of cells to run, the (x,y,z) size of item being processed
        println!("Number of workgroups dispatched: {}", num_workgroups_x);
    }

    // Sets adds copy operation to command encoder.
    // Will copy data from storage buffer on GPU to staging buffer on CPU.
    encoder.copy_buffer_to_buffer(&storage_buffer, 0, &staging_buffer, 0, size);

    // Submits command encoder for processing
    queue.submit(Some(encoder.finish()));

    // Note that we're not calling `.await` here.
    let buffer_slice = staging_buffer.slice(..);
    // Sets the buffer up for mapping, sending over the result of the mapping back to us when it is finished.
    let (sender, receiver) = futures_intrusive::channel::shared::oneshot_channel();
    buffer_slice.map_async(wgpu::MapMode::Read, move |v| sender.send(v).unwrap());
    let sw = Stopwatch::start_new();

    // Poll the device in a blocking manner so that our future resolves.
    // In an actual application, `device.poll(...)` should
    // be called in an event loop or on another thread.
    device.poll(wgpu::Maintain::Wait);

    // Awaits until `buffer_future` can be read from
    if let Some(Ok(())) = receiver.receive().await {
        println!("GPU took {}ms", sw.elapsed_ms());
        // Gets contents of buffer
        let data = buffer_slice.get_mapped_range();
        // Since contents are got in bytes, this converts these bytes back to u32
        let result = bytemuck::cast_slice(&data).to_vec();

        // With the current interface, we have to make sure all mapped views are
        // dropped before we unmap the buffer.
        drop(data);
        staging_buffer.unmap(); // Unmaps buffer from memory
                                // If you are familiar with C++ these 2 lines can be thought of similarly to:
                                //   delete myPointer;
                                //   myPointer = NULL;
                                // It effectively frees the memory

        // Returns data from buffer
        Some(result)
    } else {
        panic!("failed to run compute on gpu!")
    }
}

pub fn operation(val: u32) -> u32 {
    let mut result = Wrapping(val);
    for _ in 0..32768 {
        result = result * result * result + Wrapping(3);
    }
    result.0
}

#[test]
pub fn test_parallel() {
    //let num_inputs = 2u32.pow(16) as usize;
    let num_inputs = 256;
    println!("Performing 32768 iterations of (x^3 + 3) on {} input values.", num_inputs);
  
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
    let result = pollster::block_on(parallel(input_as_bytes)).unwrap();

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
