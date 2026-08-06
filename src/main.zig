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

const scene = @import("scene.zig");
const HittableList = scene.HittableList;

const sphere = @import("sphere.zig");
const Sphere = sphere.Sphere;

const Interval = @import("interval.zig").interval;

const camera = @import("camera.zig");
const Camera = camera.Camera;

const material = @import("material.zig");
const Material = material.Material;

pub fn main() !void {
    var threaded = std.Io.Threaded.init(std.heap.page_allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const allocator = std.heap.page_allocator;

    //Scene
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

    //Render settings
    //TODO: pull this from a file at runtime, so there's no need to recompile
    var cam: Camera = .{
        .aspectRatio = comptime 16.0 / 9.0,
        .imageWidth = 1920,
        .samplesPerPixel = 500,
        .maxBounceDepth = 20,
    };

    var outputFile = try std.Io.Dir.cwd().createFile(io, "output.ppm", .{});
    defer outputFile.close(io);

    //Writers
    var errBuffer: [256]u8 = undefined;
    var errWriter = std.Io.File.Writer.initStreaming(std.Io.File.stderr(), io, &errBuffer);
    const stderr = &errWriter.interface;
    defer errWriter.interface.flush() catch {};

    var outBuffer: [16384]u8 = undefined;
    var fileWriter = outputFile.writer(io, &outBuffer);
    const outFile = &fileWriter.interface;

    const renderStart = std.Io.Clock.awake.now(io);
    try cam.render(&world, outFile, stderr);
    const renderEnd = std.Io.Clock.awake.now(io);

    const renderDuration = renderStart.durationTo(renderEnd);

    try stderr.print("Render info: \n", .{});
    try stderr.print("  - aspect ratio: {}x{}. \n", .{ cam.imageWidth, cam.imageHeight });
    try stderr.print("  - samples per pixel: {}. \n", .{cam.samplesPerPixel});
    try stderr.print("  - ray bounce depth: {}. \n", .{cam.maxBounceDepth});
    try stderr.print("Finished in {} ms. \n", .{renderDuration.toMilliseconds()});
    try stderr.flush();
}
