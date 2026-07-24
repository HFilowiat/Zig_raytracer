const std = @import("std");

const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;
const Point3 = vec3.Vec3;

const color = @import("color.zig");
const Color = color.Color;

const ray = @import("ray.zig");
const Ray = ray.Ray;

const hittable = @import("hittable.zig");
const HitRecord = hittable.hitRecord;
const Hittable = hittable.Hittable;

const rtweekend = @import("rtweekend.zig");

const hittable_list = @import("hittable_list.zig");
const HittableList = hittable_list.HittableList;

const sphere = @import("sphere.zig");
const Sphere = sphere.Sphere;

const Interval = @import("interval.zig").interval;

const material = @import("material.zig");

//TODO: Look at this file and rewrite into something more sensible

pub const Camera = struct {
    //public in the original c++
    aspectRatio: f64 = 1.0,
    imageWidth: usize = 100,
    samplesPerPixel: usize = 10,
    maxBounceDepth: usize = 10,

    //private in the original c++
    imageHeight: usize = undefined,
    center: Point3 = undefined,
    pixel00_loc: Point3 = undefined,
    pixelDeltaU: Vec3 = undefined,
    pixelDeltaV: Vec3 = undefined,
    pixelSamplesScale: f64 = undefined,

    //Stuff that I've moved or added compered to c++
    white: Vec3 = @splat(1.0),
    black: Vec3 = @splat(0.0),
    skyBlue: Vec3 = .{ 0.5, 0.7, 1.0 },

    const JobContext = struct {
        cam: *Camera,
        world: *HittableList,
        buffer: []u8,
        rowCounter: *usize,
        totalRows: usize,
    };

    //Does the rendering
    //NOTE: If I didn't make this multithreaded implementation fucked up gpt style it will be a miracle
    fn processRows(ctx: JobContext, stderr: anytype) !void {
        const cam = ctx.cam;
        const world = ctx.world;
        const buffer = ctx.buffer;

        var prevProgress: usize = 0;

        while (true) {
            const y = @atomicRmw(usize, ctx.rowCounter, .Add, 1, .seq_cst);
            if (y >= ctx.totalRows) break;

            for (0..cam.imageWidth) |x| {
                var pixelColor: Color = @splat(0.0);
                for (0..cam.samplesPerPixel) |_| {
                    const r = cam.getRay(x, y);
                    pixelColor = pixelColor + cam.rayColor(r, cam.maxBounceDepth, world);
                }
                pixelColor = pixelColor * @as(Vec3, @splat(cam.pixelSamplesScale));

                const idx = (y * cam.imageWidth + x) * 3;
                const bytes = color.colorToBytes(pixelColor);
                buffer[idx] = bytes[0];
                buffer[idx + 1] = bytes[1];
                buffer[idx + 2] = bytes[2];
            }

            //The threads overwrite each other here
            //It makes the counter 'flicker' a bit sometimes
            //but that's fine since I just want to know the render isn't stuck
            //Idealy each thread would do it's own progress report, but I'm lazy
            const progress: usize = (y * 100) / ctx.totalRows;
            if (progress != (prevProgress)) {
                prevProgress = progress;
                stderr.print("{}%\r", .{progress}) catch {};
                stderr.flush() catch {};
            }
        }
    }

    ///Handles the threads and write loop
    pub fn render(self: *Camera, world: *HittableList, writer: anytype, stderr: anytype) !void {
        try self.init();

        //PPM file header
        try writer.print("P6\n{0} {1}\n255\n", .{ self.imageWidth, self.imageHeight });

        const totalPixels = self.imageHeight * self.imageWidth;

        var rowCounter: usize = 0;

        const numThreads = std.Thread.getCpuCount() catch 1;
        const threads = try std.heap.c_allocator.alloc(std.Thread, numThreads);
        defer std.heap.c_allocator.free(threads);

        // Allocate raw pixel buffer for binary output
        const pixelBytes = try std.heap.c_allocator.alloc(u8, totalPixels * 3);
        defer std.heap.c_allocator.free(pixelBytes);

        //Create shared context
        const ctx = JobContext{
            .cam = self,
            .world = world,
            .buffer = pixelBytes,
            .rowCounter = &rowCounter,
            .totalRows = self.imageHeight,
        };

        //Spawn threads
        for (0..numThreads) |i| {
            threads[i] = try std.Thread.spawn(.{}, processRows, .{ ctx, stderr });
        }

        //Wait for all threads to complete
        for (threads) |*t| {
            t.*.join();
        }

        //Write pixels
        try writer.writeAll(pixelBytes);
        try writer.flush();
    }

    fn init(self: *Camera) !void {
        const imageHeightFloat: f64 = @as(f64, @floatFromInt(self.imageWidth)) / self.aspectRatio;
        self.imageHeight = @intFromFloat(imageHeightFloat);
        if (self.imageHeight < 1) {
            self.imageHeight = 1;
        }

        self.pixelSamplesScale = 1.0 / @as(f64, @floatFromInt(self.samplesPerPixel));

        const focalLength: f64 = 1.0;
        const viewportHeight: f64 = 2.0;
        const viewportWidth: f64 = viewportHeight * @as(f64, @floatFromInt(self.imageWidth)) / @as(f64, @floatFromInt(self.imageHeight));
        self.center = @splat(0.0);

        const viewportU: Vec3 = .{ viewportWidth, 0.0, 0.0 };
        const viewportV: Vec3 = .{ 0.0, -viewportHeight, 0.0 };

        self.pixelDeltaU = viewportU / @as(Vec3, @splat(@as(f64, @floatFromInt(self.imageWidth))));
        self.pixelDeltaV = viewportV / @as(Vec3, @splat(@as(f64, @floatFromInt(self.imageHeight))));

        const viewportUpperLeft: Vec3 = self.center - @Vector(3, f64){ 0.0, 0.0, focalLength } - viewportU / @as(Vec3, @splat(2.0)) - viewportV / @as(Vec3, @splat(2.0));

        self.pixel00_loc = viewportUpperLeft + self.pixelDeltaU * @as(Vec3, @splat(0.5)) + self.pixelDeltaV * @as(Vec3, @splat(0.5));
    }

    inline fn sampleSquare(self: *Camera) Vec3 {
        _ = self;
        return .{
            rtweekend.floatRangeLessThan(f64, -0.5, 0.5),
            rtweekend.floatRangeLessThan(f64, -0.5, 0.5),
            0.0,
        };
    }

    inline fn getRay(self: *Camera, x: usize, y: usize) Ray {
        const offset = self.sampleSquare();

        const xFloat: f64 = @as(f64, @floatFromInt(x));
        const yFloat: f64 = @as(f64, @floatFromInt(y));

        const pixelSample = self.pixel00_loc + self.pixelDeltaU * @as(Vec3, @splat(xFloat + offset[0])) + self.pixelDeltaV * @as(Vec3, @splat(yFloat + offset[1]));

        const rayDirection = pixelSample - self.center;
        return Ray.init(self.center, rayDirection);
    }

    fn rayColor(self: *Camera, r: Ray, depth: usize, world: *HittableList) Color {
        var currentRay = r;
        var currentDepth = depth;
        //Accumulates color from all bounces, each hit multiplies this by the material's attenuation color
        var accumColor: Vec3 = @splat(1.0);

        //raytrace until maxBounceDepth or hiting something that absorbs the ray
        while (currentDepth > 0) {
            var rec: HitRecord = undefined;
            //avoid acne
            const ray_t: Interval = .{ .min = 0.001, .max = rtweekend.infinity };

            if (world.hit(currentRay, ray_t, &rec)) {
                var attenuation: Color = undefined;
                var scattered: Ray = undefined;

                //determine if ray bounced or got absorbed
                if (rec.mat.scatter(currentRay, &rec, &attenuation, &scattered)) {
                    //blend the color of what ever has been git with accumulated ray color
                    accumColor = accumColor * attenuation;
                    currentRay = scattered;
                    currentDepth -= 1;
                    continue;
                } else {
                    //Ray got absorbed
                    return self.black;
                }
            } else {
                //Ray escaped the scene
                //This is the background "sky"
                const unitDirection = currentRay.direction / @as(Vec3, @splat(vec3.length(currentRay.direction)));
                const a = 0.5 * (unitDirection[1] + 1.0);
                const sky = self.white * @as(Vec3, @splat(1.0 - a)) + self.skyBlue * @as(Vec3, @splat(a));
                return accumColor * sky;
            }
        }

        //while loop ended, maxBounceDepth reached
        return self.black;
    }
};
