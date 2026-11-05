const std = @import("std");

const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;
const Point3 = vec3.Vec3;

const color = @import("color.zig");
const Color = color.Color;

const ray = @import("ray.zig");
const Ray = ray.Ray;

const hitRecord = @import("hitRecord.zig");
const HitRecord = hitRecord.hitRecord;

const rtweekend = @import("rtweekend.zig");

const Interval = @import("interval.zig").interval;

const scene = @import("scene.zig");
const HittableList = scene.HittableList;

//TODO: Look at this file and rewrite into something more sensible

pub const Camera = struct {
    //public in the original c++
    aspectRatio: f32 = 1.0,
    imageWidth: usize = 100,
    samplesPerPixel: u32 = 10,
    maxBounceDepth: u32 = 10,

    //private in the original c++
    imageHeight: usize = undefined,
    center: Point3 = undefined,
    pixel00_loc: Point3 = undefined,
    pixelDeltaU: Vec3 = undefined,
    pixelDeltaV: Vec3 = undefined,
    pixelSamplesScale: f32 = undefined,

    //Stuff that I've moved or added compered to c++
    white: Vec3 = @splat(1.0),
    black: Vec3 = @splat(0.0),
    skyBlue: Vec3 = .{ 0.5, 0.7, 1.0, 0.0 },

    const JobContext = struct {
        cam: *Camera,
        world: *const HittableList,
        buffer: []u8,
        rowCounter: *std.atomic.Value(usize),
        totalRows: usize,
        progress: std.Progress.Node,
    };

    //Does the rendering
    fn processRows(ctx: JobContext) !void {
        @setFloatMode(.optimized);
        const cam = ctx.cam;
        const world: *const HittableList = ctx.world;
        const buffer = ctx.buffer;

        while (true) {
            const y = ctx.rowCounter.fetchAdd(1, .monotonic);
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
            ctx.progress.completeOne();
        }
    }

    ///Handles the threads and write loop
    pub fn render(
        self: *Camera,
        io: std.Io,
        allocator: std.mem.Allocator,
        world: *const HittableList,
        writer: anytype,
    ) !void {
        try self.init();

        //PPM file header
        try writer.print("P6\n{0} {1}\n255\n", .{ self.imageWidth, self.imageHeight });

        const progress = std.Progress.start(io, .{ .root_name = "render" });
        defer progress.end();

        const rows = progress.start("rows", self.imageHeight);
        defer rows.end();

        const totalPixels = self.imageHeight * self.imageWidth;

        var rowCounter: std.atomic.Value(usize) = .init(0);

        //TODO: allow passing number of threads as cli arg instead of getting all of them always
        const numThreads = std.Thread.getCpuCount() catch 1;

        // Allocate raw pixel buffer for binary output
        const pixelBytes = try allocator.alloc(u8, totalPixels * 3);
        defer allocator.free(pixelBytes);

        //Create shared context
        const ctx = JobContext{
            .cam = self,
            .world = world,
            .buffer = pixelBytes,
            .rowCounter = &rowCounter,
            .totalRows = self.imageHeight,
            .progress = rows,
        };

        var group: std.Io.Group = .init;
        defer group.cancel(io);

        for (0..numThreads) |_| {
            try group.concurrent(io, processRows, .{ctx});
        }

        try group.await(io);

        //Write pixels
        try writer.writeAll(pixelBytes);
        try writer.flush();
    }

    fn init(self: *Camera) !void {
        const imageHeightFloat: f32 = @as(f32, @floatFromInt(self.imageWidth)) / self.aspectRatio;
        self.imageHeight = @intFromFloat(imageHeightFloat);
        if (self.imageHeight < 1) {
            self.imageHeight = 1;
        }

        self.pixelSamplesScale = 1.0 / @as(f32, @floatFromInt(self.samplesPerPixel));

        const focalLength: f32 = 1.0;
        const viewportHeight: f32 = 2.0;
        const viewportWidth: f32 = viewportHeight * @as(f32, @floatFromInt(self.imageWidth)) / @as(f32, @floatFromInt(self.imageHeight));
        self.center = @splat(0.0);

        const viewportU: Vec3 = .{ viewportWidth, 0.0, 0.0, 0.0 };
        const viewportV: Vec3 = .{ 0.0, -viewportHeight, 0.0, 0.0 };

        self.pixelDeltaU = viewportU / @as(Vec3, @splat(@as(f32, @floatFromInt(self.imageWidth))));
        self.pixelDeltaV = viewportV / @as(Vec3, @splat(@as(f32, @floatFromInt(self.imageHeight))));

        const viewportUpperLeft: Vec3 = self.center - vec3.vec3(0.0, 0.0, focalLength) - viewportU / @as(Vec3, @splat(2.0)) - viewportV / @as(Vec3, @splat(2.0));

        self.pixel00_loc = viewportUpperLeft + self.pixelDeltaU * @as(Vec3, @splat(0.5)) + self.pixelDeltaV * @as(Vec3, @splat(0.5));
    }

    inline fn sampleSquare(self: *Camera) Vec3 {
        _ = self;
        return .{
            rtweekend.floatRangeLessThan(-0.5, 0.5),
            rtweekend.floatRangeLessThan(-0.5, 0.5),
            0.0,
            0.0,
        };
    }

    inline fn getRay(self: *Camera, x: usize, y: usize) Ray {
        @setFloatMode(.optimized);
        const offset = self.sampleSquare();

        const xFloat: f32 = @as(f32, @floatFromInt(x));
        const yFloat: f32 = @as(f32, @floatFromInt(y));

        const pixelSample = self.pixel00_loc + self.pixelDeltaU * @as(Vec3, @splat(xFloat + offset[0])) + self.pixelDeltaV * @as(Vec3, @splat(yFloat + offset[1]));

        const rayDirection = pixelSample - self.center;
        return Ray.init(self.center, rayDirection);
    }

    fn rayColor(self: *Camera, r: Ray, depth: u32, world: *const HittableList) Color {
        @setFloatMode(.optimized);
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
                if (rec.mat.scatter(currentRay, rec.p, rec.normal, &attenuation, &scattered)) {
                    //blend the color of whatever has been hit with accumulated ray color
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
