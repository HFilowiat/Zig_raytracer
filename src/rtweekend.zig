const std = @import("std");

pub const infinity: f32 = std.math.inf(f32);

var seedCounter = std.atomic.Value(u64).init(0);

//Per thread PRNG
threadlocal var prng: ?std.Random.DefaultPrng = null;

fn getRand() std.Random {
    if (prng == null) {
        prng = std.Random.DefaultPrng.init(seedCounter.fetchAdd(1, .monotonic));
    }
    return prng.?.random();
}

//In range std function for int but not float?
//I just might be blind though
//A wrapper is fine for this I guess

inline fn randFloatUnit() f32 {
    const bits = getRand().int(u32);
    return @as(f32, @floatFromInt(bits >> 8)) * (1.0 / 16777216.0); // [0,1], 24 bit
}

pub fn floatRangeLessThan(at_least: f32, less_than: f32) f32 {
    @setFloatMode(.optimized);
    return at_least + randFloatUnit() * (less_than - at_least);
}
