const std = @import("std");
const rtweekend = @import("rtweekend.zig");

// NOTE: Changing this from @Vector(3, f64) leaves me with a pointless .w
// but it's still getting better performance.
// Might try to use it for something letter, but no idea for anything usefull rightnow.
pub const Vec3 = @Vector(4, f32);

pub fn vec3(x: f32, y: f32, z: f32) Vec3 {
    return .{ x, y, z, 0.0 };
}

pub fn zero() Vec3 {
    return @splat(0.0);
}

pub fn divide(self: Vec3, d: f32) Vec3 {
    return self / @as(Vec3, @splat(d));
}

pub fn lengthSquared(self: Vec3) f32 {
    @setFloatMode(.optimized);
    return @reduce(.Add, self * self);
}

pub fn length(self: Vec3) f32 {
    @setFloatMode(.optimized);
    return @sqrt(lengthSquared(self));
}

pub fn nearZero(self: Vec3) bool {
    @setFloatMode(.optimized);
    const s: f32 = 1e-8;
    return @reduce(.And, @abs(self) < @as(Vec3, @splat(s)));
}

pub fn dot(a: Vec3, b: Vec3) f32 {
    @setFloatMode(.optimized);
    return @reduce(.Add, a * b);
}

pub fn reflect(v: Vec3, n: Vec3) Vec3 {
    @setFloatMode(.optimized);
    return v - n * @as(Vec3, @splat(2.0 * dot(v, n)));
}

pub fn refract(uv: Vec3, n: Vec3, etaiOverEtat: f32) Vec3 {
    const cosTheta = @min(dot(-uv, n), 1.0);
    const rOutPerp = (uv + n * @as(Vec3, @splat(cosTheta))) * @as(Vec3, @splat(etaiOverEtat));
    const tmp = 1.0 - @reduce(.Add, rOutPerp * rOutPerp);
    if (tmp <= 0.0) return zero();
    return rOutPerp + n * @as(Vec3, @splat(-@sqrt(tmp)));
}

//Marsaglia
pub fn randomUnit() Vec3 {
    @setFloatMode(.optimized);
    while (true) {
        const u = rtweekend.floatRangeLessThan(-1.0, 1.0);
        const v = rtweekend.floatRangeLessThan(-1.0, 1.0);
        const s = u * u + v * v;
        if (s < 1.0) {
            const t = @sqrt(1.0 - s);
            return .{ 2.0 * u * t, 2.0 * v * t, 1.0 - 2.0 * s, 0.0 };
        }
    }
}
