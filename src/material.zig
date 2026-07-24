const std = @import("std");

const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;
const Point3 = vec3.Vec3;

const ray = @import("ray.zig");
const Ray = ray.Ray;

const Interval = @import("interval.zig").interval;

const hittable = @import("hittable.zig");
const HitRecord = hittable.hitRecord;
const Hittable = hittable.Hittable;

const color = @import("color.zig");
const Color = color.Color;

pub const MaterialVTable = struct {
    scatter: *const fn (ctx: *anyopaque, r_in: Ray, rec: *const HitRecord, attenuation: *Color, scattered: *Ray) bool,
};

pub const Material = struct {
    vtable: *const MaterialVTable,
    ctx: *anyopaque,

    pub fn scatter(m: Material, r_in: Ray, rec: *const HitRecord, attenuation: *Color, scattered: *Ray) bool {
        return m.vtable.scatter(m.ctx, r_in, rec, attenuation, scattered);
    }
};

//Lambertian

fn lambertianScatter(ctx: *anyopaque, r_in: Ray, rec: *const HitRecord, attenuation: *Color, scattered: *Ray) bool {
    const self: *Lambertian = @ptrCast(@alignCast(ctx));
    return self.scatter(r_in, rec, attenuation, scattered);
}

pub const LambertianVTable = MaterialVTable{
    .scatter = lambertianScatter,
};

pub const Lambertian = struct {
    albedo: Color,

    pub fn init(albedo: Color) Lambertian {
        return .{ .albedo = albedo };
    }

    pub fn asMaterial(self: *Lambertian) Material {
        return .{
            .vtable = &LambertianVTable,
            .ctx = self,
        };
    }

    pub fn scatter(self: *Lambertian, r_in: Ray, rec: *const HitRecord, attenuation: *Color, scattered: *Ray) bool {
        _ = r_in;

        var scatterDirection = rec.normal + vec3.randomUnit();

        if (vec3.nearZero(scatterDirection)) {
            scatterDirection = rec.normal;
        }

        scattered.* = Ray.init(rec.p, scatterDirection);
        attenuation.* = self.albedo;
        return true;
    }
};

//Metal

//There *must* be a better way to do this
//No way that this is correct
fn metalScatter(ctx: *anyopaque, r_in: Ray, rec: *const HitRecord, attenuation: *Color, scattered: *Ray) bool {
    const self: *Metal = @ptrCast(@alignCast(ctx));
    return self.scatter(r_in, rec, attenuation, scattered);
}

pub const MetalVTable = MaterialVTable{
    .scatter = metalScatter,
};

pub const Metal = struct {
    albedo: Color,
    pub fn init(albedo: Color) Metal {
        return .{ .albedo = albedo };
    }
    pub fn asMaterial(self: *Metal) Material {
        return .{
            .vtable = &MetalVTable,
            .ctx = self,
        };
    }
    pub fn scatter(self: *Metal, r_in: Ray, rec: *const HitRecord, attenuation: *Color, scattered: *Ray) bool {
        const reflected = vec3.reflect(r_in.direction, rec.normal);
        scattered.* = Ray.init(rec.p, reflected);
        attenuation.* = self.albedo;
        return true;
    }
};
