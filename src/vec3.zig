const std = @import("std");
const rtweekend = @import("rtweekend.zig");

//NOTE:This was a struct at first
//Only later did I change it to SIMD
//so that's why there's stuff like zero() (too lazy to check where I used em)

// NOTE: nr 2. Changing this from @Vector(3, f64)
// cuz I'm stupid and most operations are scalar math. Will also remove some of the unnecesary funcions form this
pub const Vec3 = @Vector(4, f32);

pub fn vec3(x: f32, y: f32, z: f32) Vec3 {
    return .{ x, y, z, 0.0 };
}

pub fn zero() Vec3 {
    return @splat(0.0);
}

pub fn scale(self: Vec3, s: f32) Vec3 {
    return self * @as(Vec3, @splat(s));
}

pub fn divide(self: Vec3, d: f32) Vec3 {
    return self / @as(Vec3, @splat(d));
}

pub fn lengthSquared(self: Vec3) f32 {
    return @reduce(.Add, self * self);
}

pub fn length(self: Vec3) f32 {
    return @sqrt(lengthSquared(self));
}

pub fn unit(self: Vec3) Vec3 {
    return self / @as(Vec3, @splat(length(self)));
}

pub fn nearZero(self: Vec3) bool {
    const s: f32 = 1e-8;
    return @reduce(.And, @abs(self) < @as(Vec3, @splat(s)));
}

pub fn dot(a: Vec3, b: Vec3) f32 {
    return @reduce(.Add, a * b);
}

pub fn lerp(a: Vec3, b: Vec3, t: f32) Vec3 {
    return a * @as(Vec3, @splat(1.0 - t)) + b * @as(Vec3, @splat(t));
}

pub fn reflect(v: Vec3, n: Vec3) Vec3 {
    return v - n * @as(Vec3, @splat(2.0 * dot(v, n)));
}

pub fn refract(uv: Vec3, n: Vec3, etaiOverEtat: f32) Vec3 {
    const cosTheta = @min(dot(-uv, n), 1.0);
    const rOutPerp = (uv + n * @as(Vec3, @splat(cosTheta))) * @as(Vec3, @splat(etaiOverEtat));
    const tmp = 1.0 - @reduce(.Add, rOutPerp * rOutPerp);
    if (tmp <= 0.0) return zero();
    return rOutPerp + n * @as(Vec3, @splat(-@sqrt(tmp)));
}

pub fn randomRangeLessThan(at_least: f32, less_than: f32) Vec3 {
    return .{
        rtweekend.floatRangeLessThan(f32, at_least, less_than),
        rtweekend.floatRangeLessThan(f32, at_least, less_than),
        rtweekend.floatRangeLessThan(f32, at_least, less_than),
        0.0,
    };
}

pub fn randomUnit() Vec3 {
    while (true) {
        const randomVec = randomRangeLessThan(-1.0, 1.0);
        const lengthSqrd = lengthSquared(randomVec);
        if (1e-160 < lengthSqrd and lengthSqrd <= 1.0) {
            return randomVec / @as(Vec3, @splat(@sqrt(lengthSqrd)));
        }
    }
}

pub fn randomOnHemisphere(normal: Vec3) Vec3 {
    const onUnitSphere = randomUnit();
    if (dot(onUnitSphere, normal) > 0.0) {
        return onUnitSphere;
    } else {
        return -onUnitSphere;
    }
}
