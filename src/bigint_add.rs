use wgpu::util::DeviceExt;
use crate::gpu::device_setup_default;
use num_bigint::BigUint;
use num_traits::identities::Zero;
use num_bigint::RandBigInt;
use stopwatch::Stopwatch;
use itertools::Itertools;

async fn bigint_add(input_bytes: &[u8]) -> Option<Vec<u32>> {
    let num_inputs = input_bytes.len() / 4;

    let (_, _, device, queue, compute_pipeline, mut encoder) = device_setup_default("src/bigint_add.wgsl").await;

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
        cpass.dispatch_workgroups(1, 1, 1); // Number of cells to run, the (x,y,z) size of item being processed
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

    // Poll the device in a blocking manner so that our future resolves.
    // In an actual application, `device.poll(...)` should
    // be called in an event loop or on another thread.
 
    let sw = Stopwatch::start_new();
    device.poll(wgpu::Maintain::Wait);

    // Awaits until `buffer_future` can be read from
    if let Some(Ok(())) = receiver.receive().await {
        println!("GPU took {}ms", sw.elapsed_ms());
        // Gets contents of buffer
        let data = buffer_slice.get_mapped_range();
        // Since contents are got in bytes, this converts these bytes back to u32
        let result: Vec<u32> = bytemuck::cast_slice(&data).to_vec();

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

pub fn split_u32(a: u32) -> [u32; 2] {
    let a_0 = (a & 0xffff0000) >> 16;
    let a_1 = a & 0x0000ffff;
    [a_0, a_1]
}

pub fn split_biguint(a: BigUint) -> Vec<u8> {
    let mut a_bytes = a.to_bytes_le().to_vec();
    assert!(a_bytes.len() <= 32);

    while a_bytes.len() < 32 {
        a_bytes.push(0u8);
    }

    let mut result = Vec::with_capacity(64);
    let mut i = 0;
    loop {
        if i >= a_bytes.len() {
            break
        }

        result.push(a_bytes[i]);
        result.push(a_bytes[i + 1]);
        result.push(0u8);
        result.push(0u8);
        i += 2;
    }

    result
}

pub fn limbs_to_bigint256(limbs: &[u32]) -> BigUint {
    let mut res = BigUint::zero();
    for (i, limb) in limbs.iter().enumerate() {
        res += BigUint::from_slice(&[2]).pow((i * 16).try_into().unwrap()) * BigUint::from_slice(&[limb.clone()]);
    }

    res
}

#[test]
pub fn test_bigint_add() {
    let num_inputs = 1024;
    let mut a_vals = Vec::with_capacity(num_inputs);
    let mut b_vals = Vec::with_capacity(num_inputs);

    // Generate input vals
    for _ in 0..num_inputs {
        let mut rng = rand::thread_rng();
        a_vals.push(rng.gen_biguint(64));
        b_vals.push(rng.gen_biguint(64));
        //a_vals.push(BigUint::from_slice(&[0xffffffffu32]));
        //b_vals.push(BigUint::from_slice(&[0x00000001u32]));
        //a_vals.push(BigUint::from_slice(&[(i + 1) as u32]));
        //b_vals.push(BigUint::from_slice(&[(i + 2) as u32]));
    }

    let mut expected = Vec::with_capacity(num_inputs);

    // Add each pair of input vals
    let sw = Stopwatch::start_new();
    for i in 0..num_inputs {
        expected.push(&a_vals[i] + &b_vals[i]);
    }
    println!("CPU took {}ms", sw.elapsed_ms());

    let mut input_as_bytes: Vec<Vec<u8>> = Vec::with_capacity(num_inputs * 2);
    for i in 0..num_inputs {
        input_as_bytes.push(split_biguint(a_vals[i].clone()));
        input_as_bytes.push(split_biguint(b_vals[i].clone()));
    }

    let input_as_bytes: Vec<u8> = input_as_bytes.into_iter().flatten().collect();

    // Send to the GPU
    let result = pollster::block_on(bigint_add(&input_as_bytes)).unwrap();

    let chunks: Vec<Vec<u32>> = result
        .into_iter().chunks(16)
        .into_iter().map(|c| c.into_iter().collect())
        .collect();

    let results_as_biguint: Vec<BigUint> = chunks.iter().map(|c| limbs_to_bigint256(c)).collect();
    //println!("{:?}", a_vals);
    //println!("{:?}", b_vals);
    //println!("{:?}", results_as_biguint);

    for i in 0..num_inputs {
        assert_eq!(results_as_biguint[i * 2], expected[i]);
    }
}
