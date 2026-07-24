const std = @import("std");

const rtweekend = @import("rtweekend.zig");

pub const interval = struct {
    min: f64,
    max: f64,

    pub fn init(min: f64, max: f64) interval {
        return interval{ .min = min, .max = max };
    }

    pub fn empty() interval {
        return interval{ .min = rtweekend.infinity, .max = -rtweekend.infinity };
    }

    pub fn size(self: interval) f64 {
        return self.max - self.min;
    }

    pub fn contains(self: interval, x: f64) bool {
        return self.min <= x and x <= self.max;
    }

    pub fn surrounds(self: interval, x: f64) bool {
        return self.min < x and x < self.max;
    }

    pub fn universe() interval {
        return interval{ .min = -rtweekend.infinity, .max = rtweekend.infinity };
    }

    pub fn clamp(self: interval, x: f64) f64 {
        if (x < self.min) return self.min;
        if (x > self.max) return self.max;

        return x;
    }
};
