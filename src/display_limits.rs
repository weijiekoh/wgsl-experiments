//use wgpu::util::DeviceExt;
//use crate::gpu::device_setup_default;

/// Print the GPU limits of the default device
async fn display_limits() {
    let instance = wgpu::Instance::default();
    let adapter = instance
        .request_adapter(&wgpu::RequestAdapterOptions::default())
        //.request_adapter(&wgpu::RequestAdapterOptions {
            //power_preference: wgpu::PowerPreference::HighPerformance,
            //force_fallback_adapter: false,
            //compatible_surface: None,
        //})
        .await.unwrap();
    let (device, _queue) = adapter
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

    let limits = device.limits();
    println!("{:?}", limits);
}

#[test]
pub fn test_display_limits() {
    pollster::block_on(display_limits());
}
