use std::borrow::Cow;

pub async fn device_setup_default(
    wgsl_source_file: &str
) -> (
    wgpu::Instance,
    wgpu::Adapter,
    wgpu::Device,
    wgpu::Queue,
    wgpu::ComputePipeline,
    wgpu::CommandEncoder,
) {
    let instance = wgpu::Instance::default();
    let adapter = instance
        //.request_adapter(&wgpu::RequestAdapterOptions::default())
        .request_adapter(&wgpu::RequestAdapterOptions {
            power_preference: wgpu::PowerPreference::HighPerformance,
            force_fallback_adapter: false,
            compatible_surface: None,
        })
        .await.unwrap();
    let (device, queue) = adapter
        .request_device(
            &wgpu::DeviceDescriptor {
                label: None,
                features: wgpu::Features::empty(),
                limits: wgpu::Limits::default(),
            },
            None,
        )
        .await
        .unwrap();

    let wgsl_source = std::fs::read_to_string(wgsl_source_file).unwrap();
    let cs_module = device.create_shader_module(wgpu::ShaderModuleDescriptor {
        label: None,
        source: wgpu::ShaderSource::Wgsl(Cow::Borrowed(&wgsl_source)),
    });

    let compute_pipeline = device.create_compute_pipeline(&wgpu::ComputePipelineDescriptor {
        label: None,
        layout: None,
        module: &cs_module,
        entry_point: "main",
    });

    // A command encoder executes one or many pipelines.
    // It is to WebGPU what a command buffer is to Vulkan.
    let encoder =
        device.create_command_encoder(&wgpu::CommandEncoderDescriptor { label: None });

    let info = adapter.get_info();
    println!("{:?}", info);

    (instance, adapter, device, queue, compute_pipeline, encoder)
}

