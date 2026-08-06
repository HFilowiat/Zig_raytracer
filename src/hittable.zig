const std = @import("std");

const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;
const Point3 = vec3.Vec3;

const ray = @import("ray.zig");
const Ray = ray.Ray;

const Interval = @import("interval.zig").interval;

const material = @import("material.zig");
const Material = material.Material;

pub const hitRecord = struct {
    p: Point3,
    normal: Vec3,
    t: f32,
    frontFace: bool,
    mat: Material,

    pub fn setFaceNormal(self: *hitRecord, r: Ray, outwardNormal: Vec3) void {
        self.frontFace = vec3.dot(r.directionValue(), outwardNormal) < 0;
        self.normal = if (self.frontFace) outwardNormal else -outwardNormal;
    }
};

pub const Hittable = struct {
    vtable: *const fn (self: *const @This(), r: Ray, ray_t: Interval, rec: *hitRecord) bool,

    pub fn hit(self: *const @This(), r: Ray, ray_t: Interval, rec: *hitRecord) bool {
        return self.vtable(self, r, ray_t, rec);
    }
};
