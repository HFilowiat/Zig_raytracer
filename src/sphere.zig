const std = @import("std");

const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;
const Point3 = vec3.Vec3;

const ray = @import("ray.zig");
const Ray = ray.Ray;

const hittable = @import("hittable.zig");
const HitRecord = hittable.hitRecord;
const Hittable = hittable.Hittable;

const Interval = @import("interval.zig").interval;

const material = @import("material.zig");
const Material = material.Material;

pub const Sphere = struct {
    center: Vec3,
    radius: f64,
    mat: Material,

    pub fn init(center: Point3, mat: Material, radius: f64) Sphere {
        return Sphere{ .center = center, .mat = mat, .radius = radius };
    }

    pub fn hit(self: *const @This(), r: Ray, ray_t: Interval, rec: *HitRecord) bool {
        const oc: Vec3 = self.center - r.origin;
        const a: f64 = vec3.lengthSquared(r.directionValue());
        const h: f64 = vec3.dot(r.directionValue(), oc);
        const c: f64 = vec3.lengthSquared(oc) - self.radius * self.radius;

        const discriminant = h * h - a * c;
        if (discriminant < 0) {
            return false;
        }
        const sqrtDiscriminant = @sqrt(discriminant);
        var root = (h - sqrtDiscriminant) / a;
        if (!ray_t.surrounds(root)) {
            root = (h + sqrtDiscriminant) / a;
            if (!ray_t.surrounds(root)) {
                return false;
            }
        }
        rec.t = root;
        rec.p = r.at(rec.t);
        const outwardNormal: Vec3 = (rec.p - self.center) / @as(Vec3, @splat(self.radius));
        rec.setFaceNormal(r, outwardNormal);
        rec.mat = self.mat;
        return true;
    }

    pub fn asHittable(self: *const @This()) Hittable {
        return Hittable{ .vtable = @ptrCast(&self.hit) };
    }
};
