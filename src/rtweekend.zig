const std = @import("std");

pub const infinity: f32 = std.math.inf(f32);

//Per thread PRNG
threadlocal var prng: std.Random.DefaultPrng = undefined;
threadlocal var prngInitialized: bool = false;

pub fn getRand() std.Random {
    if (!prngInitialized) {
        // NOTE: deterministc, but unique per thread
        const seed: u64 = @as(u64, @intFromPtr(&prng)) ^ 0x12345678;
        prng = std.Random.DefaultPrng.init(seed);
        prngInitialized = true;
    }
    return prng.random();
}

//In range std function for int but not float?
//I just might be blind though
//A wrapper is fine for this I guess
pub fn floatRangeLessThan(comptime T: type, at_least: T, less_than: T) T {
    @setFloatMode(.optimized);
    return at_least + getRand().float(T) * (less_than - at_least);
}
