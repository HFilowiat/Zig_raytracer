const std = @import("std");

const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;
const Point3 = vec3.Vec3;

const ray = @import("ray.zig");
const Ray = ray.Ray;

const hittable = @import("hittable.zig");
const HitRecord = hittable.hitRecord;
const Hittable = hittable.Hittable;

const sphere = @import("sphere.zig");
const Sphere = sphere.Sphere;

const Interval = @import("interval.zig").interval;

const material = @import("material.zig");

pub const HittableList = struct {
    objects: std.ArrayList(*Sphere),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) HittableList {
        return .{
            .objects = std.ArrayList(*Sphere).empty,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *HittableList) void {
        self.objects.deinit(self.allocator);
    }

    pub fn clear(self: *HittableList) !void {
        self.objects.clearRetainingCapacity();
    }

    pub fn add(self: *HittableList, object: *Sphere) !void {
        try self.objects.append(self.allocator, object);
    }

    pub fn destroyAll(self: *HittableList) void {
        if (self.objects.items.len > 0) {
            for (self.objects.items) |obj| {
                self.allocator.destroy(obj);
            }
            self.objects.clearRetainingCapacity();
        }
    }

    pub fn hit(self: *const HittableList, r: Ray, ray_t: Interval, rec: *HitRecord) bool {
        var tempRec: HitRecord = undefined;
        var hitAnything = false;
        var closestSoFar = ray_t.max;
        for (self.objects.items) |object| {
            if (object.hit(r, .{ .min = ray_t.min, .max = closestSoFar }, &tempRec)) {
                hitAnything = true;
                closestSoFar = tempRec.t;
                rec.* = tempRec;
            }
        }
        return hitAnything;
    }

    pub fn asHittable(self: *const @This()) Hittable {
        return Hittable{ .hit = @ptrCast(&self.hit) };
    }
};
