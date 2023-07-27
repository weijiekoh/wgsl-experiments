use wgpu::util::DeviceExt;
use crate::utils::{split_biguint, limbs_to_bigint512};
use crate::gpu::device_setup_default;
use num_bigint::BigUint;
use num_bigint::RandBigInt;
use stopwatch::Stopwatch;
use itertools::Itertools;

async fn bigint_sqr(input_bytes: &[u8]) -> Option<Vec<u32>> {
    let num_inputs = input_bytes.len() / 4;
    let (_, _, device, queue, compute_pipeline, mut encoder) = device_setup_default("src/bigint_sqr.wgsl").await;

    // Gets the size in bytes of the buffer.
    let slice_size = num_inputs * std::mem::size_of::<u32>();
    let size = slice_size as wgpu::BufferAddress;

    // Instantiates buffer without data.
    // `usage` of buffer specifies how it can be used:
    //   `BufferUsages::MAP_READ` allows it to be read (outside the shader).
    //   `BufferUsages::COPY_DST` allows it to be the destination of the copy.
    let input_staging_buffer = device.create_buffer(&wgpu::BufferDescriptor {
        label: None,
        size,
        usage: wgpu::BufferUsages::MAP_READ | wgpu::BufferUsages::COPY_DST,
        mapped_at_creation: false,
    });

    let output_staging_buffer = device.create_buffer(&wgpu::BufferDescriptor {
        label: None,
        size: size * 2,
        usage: wgpu::BufferUsages::MAP_READ | wgpu::BufferUsages::COPY_DST,
        mapped_at_creation: false,
    });

    // Instantiates buffer with data.
    // Usage allowing the buffer to be:
    //   A storage buffer (can be bound within a bind group and thus available to a shader).
    //   The destination of a copy.
    //   The source of a copy.
    let input_storage_buffer = device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
        label: Some("Input storage buffer"),
        contents: &input_bytes,
        usage: wgpu::BufferUsages::STORAGE
            | wgpu::BufferUsages::COPY_DST
            | wgpu::BufferUsages::COPY_SRC,
    });

    let output_bytes = vec![0u8; 128];
    let output_storage_buffer = device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
        label: Some("Output storage buffer"),
        contents: &output_bytes,
        usage: wgpu::BufferUsages::STORAGE
            | wgpu::BufferUsages::COPY_DST
            | wgpu::BufferUsages::COPY_SRC,
    });

    // Instantiates the bind group, once again specifying the binding of buffers.
    let bind_group_layout = compute_pipeline.get_bind_group_layout(0);
    let bind_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
        label: None,
        layout: &bind_group_layout,
        entries: &[
            wgpu::BindGroupEntry {
                binding: 0,
                resource: input_storage_buffer.as_entire_binding(),
            },
            wgpu::BindGroupEntry {
                binding: 1,
                resource: output_storage_buffer.as_entire_binding(),
            }
        ],
    });

    {
        let mut cpass = encoder.begin_compute_pass(&wgpu::ComputePassDescriptor { label: None });
        cpass.set_pipeline(&compute_pipeline);
        cpass.set_bind_group(0, &bind_group, &[]);
        cpass.insert_debug_marker("debug marker");
        cpass.dispatch_workgroups(1, 1, 1); // Number of cells to run, the (x,y,z) size of item being processed
    }

    // Sets adds copy operation to command encoder.
    // Will copy data from storage buffer on GPU to staging buffer on CPU.
    encoder.copy_buffer_to_buffer(&input_storage_buffer, 0, &input_staging_buffer, 0, size);
    encoder.copy_buffer_to_buffer(&output_storage_buffer, 0, &output_staging_buffer, 0, size * 2);

    // Submits command encoder for processing
    queue.submit(Some(encoder.finish()));

    // Sets the buffer up for mapping, sending over the result of the mapping back to us when it is finished.
    let output_buffer_slice = output_staging_buffer.slice(..);
    let (sender, receiver) = futures_intrusive::channel::shared::oneshot_channel();
    output_buffer_slice.map_async(wgpu::MapMode::Read, move |v| sender.send(v).unwrap());

    // Poll the device in a blocking manner so that our future resolves.
    // In an actual application, `device.poll(...)` should
    // be called in an event loop or on another thread.
 
    let sw = Stopwatch::start_new();
    device.poll(wgpu::Maintain::Wait);

    // Awaits until `buffer_future` can be read from
    if let Some(Ok(())) = receiver.receive().await {
        println!("GPU took {}ms", sw.elapsed_ms());
        // Gets contents of buffer
        let data = output_buffer_slice.get_mapped_range();
        // Since contents are got in bytes, this converts these bytes back to u32
        let result: Vec<u32> = bytemuck::cast_slice(&data).to_vec();

        // With the current interface, we have to make sure all mapped views are
        // dropped before we unmap the buffer.
        drop(data);
        output_staging_buffer.unmap(); // Unmaps buffer from memory
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

#[test]
pub fn test_bigint_sqr() {
    let num_inputs = 1;
    let mut vals = Vec::with_capacity(num_inputs);

    // Generate input vals
    for _ in 0..num_inputs {
        let mut rng = rand::thread_rng();
        vals.push(rng.gen_biguint(64));
        //vals.push(BigUint::from_slice(&[2u32]));
    }

    let mut expected = Vec::with_capacity(num_inputs);

    // Square each input val
    let sw = Stopwatch::start_new();
    for val in &vals {
        expected.push(val * val);
    }
    println!("CPU took {}ms", sw.elapsed_ms());

    let mut input_as_bytes: Vec<Vec<u8>> = Vec::with_capacity(num_inputs);
    for val in &vals {
        input_as_bytes.push(split_biguint(val.clone()));
    }

    let input_as_bytes: Vec<u8> = input_as_bytes.into_iter().flatten().collect();

    // Send to the GPU
    let result = pollster::block_on(bigint_sqr(&input_as_bytes)).unwrap();

    let chunks: Vec<Vec<u32>> = result
        .into_iter().chunks(32)
        .into_iter().map(|c| c.into_iter().collect())
        .collect();

    let results_as_biguint: Vec<BigUint> = chunks.iter().map(|c| limbs_to_bigint512(c)).collect();
    //println!("i: {:?}", vals);
    //println!("e: {:?}", expected);
    //println!("r: {:?}", results_as_biguint);

    for i in 0..num_inputs {
        assert_eq!(results_as_biguint[i], expected[i]);
    }
}
