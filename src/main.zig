const std = @import("std");
const chilli = @import("chilli");

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

const scene = @import("scene.zig");
const HittableList = scene.HittableList;

const sphere = @import("sphere.zig");
const Sphere = sphere.Sphere;

const Interval = @import("interval.zig").interval;

const camera = @import("camera.zig");
const Camera = camera.Camera;

const material = @import("material.zig");
const Material = material.Material;

//CLI

const RenderContext = struct {
    io: std.Io,
    world: *HittableList,
};

const RenderSettings = struct {
    width: usize,
    aspectRatio: f32,
    samplesPerPixel: u32,
    maxBounceDepth: u32,
    outputPath: []const u8,
};

fn readRenderSettings(ctx: chilli.CommandContext) !RenderSettings {
    const width_i64 = try ctx.getFlag("width", i64);
    const aspect_f64 = try ctx.getFlag("aspect", f64);
    const samples = try ctx.getFlag("samples", u32);
    const depth = try ctx.getFlag("depth", u32);
    const output_path = try ctx.getFlag("output", []const u8);

    //Basic input validation
    if (width_i64 <= 0) {
        return error.InvalidImageWidth;
    }
    if (samples == 0) {
        return error.InvalidSamplesPerPixel;
    }
    if (depth == 0) {
        return error.InvalidMaxBounceDepth;
    }
    if (output_path.len == 0) {
        return error.InvalidOutputPath;
    }

    //Using a float as aspect ratio kinda sucks
    const aspect_f32: f32 = @floatCast(aspect_f64);
    if (!std.math.isFinite(aspect_f32) or aspect_f32 <= 0.0) {
        return error.InvalidAspectRatio;
    }

    return .{
        .width = std.math.cast(usize, width_i64) orelse
            return error.InvalidImageWidth,
        .aspectRatio = aspect_f32,
        .samplesPerPixel = samples,
        .maxBounceDepth = depth,
        .outputPath = output_path,
    };
}

fn renderExec(ctx: chilli.CommandContext) !void {
    const data = ctx.getContextData(RenderContext) orelse
        return error.MissingRenderContext;

    const settings = try readRenderSettings(ctx);

    var cam: Camera = .{
        .aspectRatio = settings.aspectRatio,
        .imageWidth = settings.width,
        .samplesPerPixel = settings.samplesPerPixel,
        .maxBounceDepth = settings.maxBounceDepth,
    };

    //Printers and writers
    var output_file = try std.Io.Dir.cwd().createFile(
        data.io,
        settings.outputPath,
        .{},
    );
    defer output_file.close(data.io);

    var err_buffer: [256]u8 = undefined;
    var err_writer = std.Io.File.Writer.initStreaming(
        std.Io.File.stderr(),
        data.io,
        &err_buffer,
    );
    const stderr = &err_writer.interface;
    defer err_writer.interface.flush() catch {};

    var out_buffer: [16384]u8 = undefined;
    var file_writer = output_file.writer(data.io, &out_buffer);
    const out_file = &file_writer.interface;

    //Render wraped in a clock to measure time, I'm unsure how accurate this is
    const render_start = std.Io.Clock.awake.now(data.io);
    try cam.render(data.world, out_file, stderr);
    const render_end = std.Io.Clock.awake.now(data.io);
    const render_duration = render_start.durationTo(render_end);

    try stderr.print("Render info: \n", .{});
    try stderr.print("  - resolution: {}x{}. \n", .{ cam.imageWidth, cam.imageHeight });
    try stderr.print("  - samples per pixel: {}. \n", .{cam.samplesPerPixel});
    try stderr.print("  - ray bounce depth: {}. \n", .{cam.maxBounceDepth});
    try stderr.print("  - output: {s}. \n", .{settings.outputPath});
    try stderr.print("Finished in {} ms. \n", .{render_duration.toMilliseconds()});
    try stderr.flush();
}

pub fn main(init: std.process.Init.Minimal) !void {
    var threaded = std.Io.Threaded.init(std.heap.page_allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const allocator = std.heap.page_allocator;

    //Scene setup
    //TODO: Handling of meshes, and a JSON manifest with positions
    var world = HittableList.init(allocator);
    defer world.deinit();

    const materialGround: Material = .{ .lambertian = .{ .albedo = .{ 0.8, 0.8, 0.0, 0.0 } } };
    const materialCenter: Material = .{ .lambertian = .{ .albedo = .{ 0.1, 0.2, 0.5, 0.0 } } };
    const materialLeft: Material = .{ .metal = .{ .albedo = .{ 0.8, 0.8, 0.8, 0.0 } } };
    const materialRight: Material = .{ .metal = .{ .albedo = .{ 0.8, 0.6, 0.2, 0.0 } } };

    var ground = Sphere.init(.{ 0.0, -100.5, -1.0, 0.0 }, materialGround, 100.0);
    var center = Sphere.init(.{ 0.0, 0.0, -1.2, 0.0 }, materialCenter, 0.5);
    var left = Sphere.init(.{ -1.0, -0.3, -1.0, 0.0 }, materialLeft, 0.5);
    var right = Sphere.init(.{ 1.0, 0.0, -1.0, 0.0 }, materialRight, 0.5);
    var inLeft = Sphere.init(.{ -1.0, 0.0, -1.0, 0.0 }, materialRight, 0.3);
    var behindCamera = Sphere.init(.{ 0.0, 0.0, 1.2, 0.0 }, materialCenter, 1);

    try world.addSphere(&ground);
    try world.addSphere(&center);
    try world.addSphere(&left);
    try world.addSphere(&right);
    try world.addSphere(&inLeft);
    try world.addSphere(&behindCamera);

    var root_cmd = try chilli.Command.init(allocator, .{
        .name = "zig_raytracer",
        .description = "A multithreaded path tracer written in Zig",
        .version = "v0.1.0",
        .exec = renderExec,
    });
    defer root_cmd.deinit();

    try root_cmd.addFlag(.{
        .name = "width",
        .shortcut = 'w',
        .description = "Output image width in pixels",
        .type = .Int,
        .default_value = .{ .Int = 1920 },
    });

    try root_cmd.addFlag(.{
        .name = "aspect",
        .shortcut = 'a',
        .description = "Output aspect ratio (width / height)",
        .type = .Float,
        .default_value = .{ .Float = 16.0 / 9.0 },
    });

    try root_cmd.addFlag(.{
        .name = "samples",
        .shortcut = 's',
        .description = "Samples per pixel",
        .type = .Int,
        .default_value = .{ .Int = 500 },
    });

    try root_cmd.addFlag(.{
        .name = "depth",
        .shortcut = 'd',
        .description = "Maximum ray bounce depth",
        .type = .Int,
        .default_value = .{ .Int = 20 },
    });

    try root_cmd.addFlag(.{
        .name = "output",
        .shortcut = 'o',
        .description = "Output PPM file path",
        .type = .String,
        .default_value = .{ .String = "output.ppm" },
    });

    var render_context = RenderContext{
        .io = io,
        .world = &world,
    };

    try root_cmd.run(init.args, @ptrCast(&render_context));
}
