const std = @import("std");

const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;

pub const Color = Vec3;

const Interval = @import("interval.zig").interval;

inline fn linearToGamma(linearComponent: f32) f32 {
    if (linearComponent > 0.0) {
        return std.math.sqrt(linearComponent);
    }
    return 0.0;
}

pub fn colorToBytes(pixel_color: Color) [3]u8 {
    var r: f32 = pixel_color[0];
    var g: f32 = pixel_color[1];
    var b: f32 = pixel_color[2];

    r = linearToGamma(r);
    g = linearToGamma(g);
    b = linearToGamma(b);

    r = @min(@max(r, 0.0), 0.999999999999);
    g = @min(@max(g, 0.0), 0.999999999999);
    b = @min(@max(b, 0.0), 0.999999999999);
    const intensity: Interval = Interval.init(0.000, 0.999);
    return .{
        @intFromFloat(256 * intensity.clamp(r)),
        @intFromFloat(256 * intensity.clamp(g)),
        @intFromFloat(256 * intensity.clamp(b)),
    };
}
