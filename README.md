# WGSL Experiments

## Simple parallelism benchmark

Clone this repository and run the `parallel` test:

```bash
cargo test parallel --release --nocapture
```

### About parallelism

Parallelism in GPU is controlled by two factors: the workgroup size (apparently it's max 256) and the number of workgroups dispatched. It seems that WGPU automatically divides the input buffer such that each workgroup receives at least the right slice of data to work on.

```
Workgroup size: 256

Performing 1048576 iterations of (x^2 + 3) on 8192 input values.
CPU took 8049ms
Number of workgroups dispatched: 256
GPU took 2220ms


Performing 1048576 iterations of (x^2 + 3) on 8192 input values.
CPU took 9215ms
Number of workgroups dispatched: 128
GPU took 985ms

Performing 1048576 iterations of (x^2 + 3) on 8192 input values.
CPU took 7911ms
Number of workgroups dispatched: 64
GPU took 475ms

Performing 1048576 iterations of (x^2 + 3) on 8192 input values.
CPU took 7612ms
Number of workgroups dispatched: 32
GPU took 263ms
```

The GPU does not work on all the inputs if fewer than 32 workgroups are dispatched. This makes sense because the number of inputs divided by the workgroup size is 32. Furthermore, the performance is worse if the number of workgroups is larger than 32, which also makes sense as that makes the GPU does unnecessary work.

If we change the workgroup size to 32 and dispatch 256 workgroups (256 * 32 = 8192), the above principle holds:

```
Workgroup size: 32
Performing 1048576 iterations of (x^2 + 3) on 8192 input values.
CPU took 7613ms
Number of workgroups dispatched: 256
GPU took 267ms
```
