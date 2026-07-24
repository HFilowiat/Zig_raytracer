const std = @import("std");
const rtweekend = @import("rtweekend.zig");

//NOTE:This was a struct at first
//Only later did I change it to SIMD
//so that's why there's stuff like zero() (too lazy to check where I used em)
pub const Vec3 = @Vector(3, f64);

pub fn vec3(x: f64, y: f64, z: f64) Vec3 {
    return .{ x, y, z };
}

pub fn zero() Vec3 {
    return @splat(0.0);
}

pub fn scale(self: Vec3, s: f64) Vec3 {
    return self * @as(Vec3, @splat(s));
}

pub fn divide(self: Vec3, d: f64) Vec3 {
    return self / @as(Vec3, @splat(d));
}

pub fn lengthSquared(self: Vec3) f64 {
    return @reduce(.Add, self * self);
}

pub fn length(self: Vec3) f64 {
    return @sqrt(lengthSquared(self));
}

pub fn unit(self: Vec3) Vec3 {
    return self / @as(Vec3, @splat(length(self)));
}

pub fn nearZero(self: Vec3) bool {
    const s: f64 = 1e-8;
    return @reduce(.And, @abs(self) < @as(Vec3, @splat(s)));
}

pub fn toArray(self: Vec3) [3]f64 {
    return self;
}

pub fn dot(a: Vec3, b: Vec3) f64 {
    return @reduce(.Add, a * b);
}

pub fn cross(a: Vec3, b: Vec3) Vec3 {
    return .{
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    };
}

pub fn lerp(a: Vec3, b: Vec3, t: f64) Vec3 {
    return a * @as(Vec3, @splat(1.0 - t)) + b * @as(Vec3, @splat(t));
}

pub fn reflect(v: Vec3, n: Vec3) Vec3 {
    return v - n * @as(Vec3, @splat(2.0 * dot(v, n)));
}

pub fn refract(uv: Vec3, n: Vec3, etaiOverEtat: f64) Vec3 {
    const cosTheta = @min(dot(-uv, n), 1.0);
    const rOutPerp = (uv + n * @as(Vec3, @splat(cosTheta))) * @as(Vec3, @splat(etaiOverEtat));
    const tmp = 1.0 - @reduce(.Add, rOutPerp * rOutPerp);
    if (tmp <= 0.0) return zero();
    return rOutPerp + n * @as(Vec3, @splat(-@sqrt(tmp)));
}

pub fn random() Vec3 {
    return .{
        rtweekend.floatRangeLessThan(f64, 0.0, 1.0),
        rtweekend.floatRangeLessThan(f64, 0.0, 1.0),
        rtweekend.floatRangeLessThan(f64, 0.0, 1.0),
    };
}

pub fn randomRangeLessThan(at_least: f64, less_than: f64) Vec3 {
    return .{
        rtweekend.floatRangeLessThan(f64, at_least, less_than),
        rtweekend.floatRangeLessThan(f64, at_least, less_than),
        rtweekend.floatRangeLessThan(f64, at_least, less_than),
    };
}

pub fn randomUnit() Vec3 {
    //while (true) {
    //    const randomVec = randomRangeLessThan(-1.0, 1.0);
    //   const lengthSqrd = lengthSquared(randomVec);
    //  if (1e-160 < lengthSqrd and lengthSqrd <= 1.0) {
    //     return randomVec / @as(Vec3, @splat(@sqrt(lengthSqrd)));
    //   }
    //}
    const phi = rtweekend.floatRangeLessThan(f64, 0.0, 2.0 * rtweekend.pi);
    const cosTheta = rtweekend.floatRangeLessThan(f64, -1.0, 1.0);
    const sinTheta = @sqrt(1.0 - cosTheta * cosTheta);
    return .{
        sinTheta * @cos(phi),
        sinTheta * @sin(phi),
        cosTheta,
    };
}

pub fn randomOnHemisphere(normal: Vec3) Vec3 {
    const onUnitSphere = randomUnit();
    if (dot(onUnitSphere, normal) > 0.0) {
        return onUnitSphere;
    } else {
        return -onUnitSphere;
    }
}
