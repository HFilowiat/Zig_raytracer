const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;
const Point3 = Vec3;

const ray = @import("ray.zig");
const Ray = ray.Ray;

const Color = Vec3;

//Lambertian

pub const Lambertian = struct {
    albedo: Color,

    pub fn scatter(self: *const Lambertian, r_in: Ray, p: Point3, normal: Vec3, attenuation: *Color, scattered: *Ray) bool {
        @setFloatMode(.optimized);
        _ = r_in;

        var scatterDirection = normal + vec3.randomUnit();

        if (vec3.nearZero(scatterDirection)) {
            scatterDirection = normal;
        }

        scattered.* = Ray.init(p, scatterDirection);
        attenuation.* = self.albedo;
        return true;
    }
};

//Metal

pub const Metal = struct {
    albedo: Color,

    pub fn scatter(self: *const Metal, r_in: Ray, p: Point3, normal: Vec3, attenuation: *Color, scattered: *Ray) bool {
        @setFloatMode(.optimized);
        scattered.* = Ray.init(p, vec3.reflect(r_in.direction, normal));
        attenuation.* = self.albedo;
        return true;
    }
};

pub const Material = union(enum) {
    lambertian: Lambertian,
    metal: Metal,

    pub fn scatter(self: Material, r_in: Ray, p: Point3, normal: Vec3, attenuation: *Color, scattered: *Ray) bool {
        return switch (self) {
            .lambertian => |m| m.scatter(r_in, p, normal, attenuation, scattered),
            .metal => |m| m.scatter(r_in, p, normal, attenuation, scattered),
        };
    }
};
