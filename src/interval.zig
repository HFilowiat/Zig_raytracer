const std = @import("std");

const rtweekend = @import("rtweekend.zig");

pub const interval = struct {
    min: f32,
    max: f32,

    pub fn init(min: f32, max: f32) interval {
        return interval{ .min = min, .max = max };
    }

    pub fn empty() interval {
        return interval{ .min = rtweekend.infinity, .max = -rtweekend.infinity };
    }

    pub fn size(self: interval) f32 {
        return self.max - self.min;
    }

    pub fn contains(self: interval, x: f32) bool {
        return self.min <= x and x <= self.max;
    }

    pub fn surrounds(self: interval, x: f32) bool {
        return self.min < x and x < self.max;
    }

    pub fn universe() interval {
        return interval{ .min = -rtweekend.infinity, .max = rtweekend.infinity };
    }

    pub fn clamp(self: interval, x: f32) f32 {
        if (x < self.min) return self.min;
        if (x > self.max) return self.max;

        return x;
    }
};
