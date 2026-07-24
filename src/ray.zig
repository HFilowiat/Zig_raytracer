const std = @import("std");

const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;
const Point3 = vec3.Vec3;

// NOTE: original C++ uses private fields
// Zig doesnt have per field private, I think
// If the need arises, and I will need to emulate private
// Keeping the struct away from pub and exporting functions might work

pub const Ray = struct {
    origin: Point3,
    direction: Vec3,

    pub fn init(origin: Point3, direction: Vec3) Ray {
        return Ray{ .origin = origin, .direction = direction };
    }

    pub fn directionValue(self: Ray) Vec3 {
        return self.direction;
    }

    pub fn at(self: Ray, t: f64) Point3 {
        return self.origin + self.direction * @as(Vec3, @splat(t));
    }
};
