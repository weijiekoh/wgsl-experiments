//use wgpu::util::DeviceExt;
//use crate::gpu::device_setup_default;

/// Print the GPU limits of the default device
async fn display_limits() {
}

#[test]
pub fn test_parallel_double() {
    pollster::block_on(display_limits());
}
