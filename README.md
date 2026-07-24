# zig_raytracer

A multithreaded path tracer written in Zig, based on the book series [Ray Tracing in One Weekend](https://raytracing.github.io/books/RayTracingInOneWeekend.html).

## Difrences from the series
- SIMD vector math
- Multithreaded rendering
- PPM image output is in binary

## Build Requirements

- Zig, tested on 0.16.0
- [GLFW](https://www.glfw.org/) development libraries
- OpenGL development libraries

### Installing dependencies

**Fedora:**

```sh
sudo dnf install glfw-devel mesa-libGL-devel
```

## Build Instructions

```sh
zig build
```

## Usage
Run the built program at `./zig-out/bin/zig_raytracer`.

This renders the default scene to `output.ppm`, in the same directory.

