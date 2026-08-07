const std = @import("std");

const hitRecord = @import("hitRecord.zig");
const HitRecord = hitRecord.hitRecord;

const ray = @import("ray.zig");
const Ray = ray.Ray;

const Interval = @import("interval.zig").interval;

const sphere = @import("sphere.zig");
const Sphere = sphere.Sphere;

pub const Hittable = union(enum) {
    sphere: *const Sphere,
    list: *const HittableList,

    pub fn hit(self: Hittable, r: Ray, ray_t: Interval, rec: *HitRecord) bool {
        return switch (self) {
            .sphere => |s| s.hit(r, ray_t, rec),
            .list => |l| l.hit(r, ray_t, rec),
        };
    }
};

pub const HittableList = struct {
    objects: std.ArrayList(Hittable),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) HittableList {
        return .{
            .objects = .empty,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *HittableList) void {
        self.objects.deinit(self.allocator);
    }

    pub fn add(self: *HittableList, object: Hittable) !void {
        try self.objects.append(self.allocator, object);
    }

    pub fn addSphere(self: *HittableList, sphereObject: *const Sphere) !void {
        try self.add(.{ .sphere = sphereObject });
    }

    pub fn hit(self: *const HittableList, r: Ray, ray_t: Interval, rec: *HitRecord) bool {
        var tempRec: HitRecord = undefined;
        var hitAnything: bool = false;
        var closestSoFar: f32 = ray_t.max;

        for (self.objects.items) |*object| {
            if (object.hit(r, .{ .min = ray_t.min, .max = closestSoFar }, &tempRec)) {
                hitAnything = true;
                closestSoFar = tempRec.t;
                rec.* = tempRec;
            }
        }
        return hitAnything;
    }
};
