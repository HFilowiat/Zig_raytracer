const std = @import("std");

pub const infinity: f64 = std.math.inf(f64);
pub const pi: f64 = 3.1415926535897932385;
pub fn degreesToRadians(degrees: f64) f64 {
    return degrees * pi / 180.0;
}

//Hope this isn't fully stupid
threadlocal var prng = std.Random.DefaultPrng.init(12345678);
pub fn getRand() std.Random {
    return prng.random();
}

//In range std function for int but not float?
//I just might be blind though
//A wrapper is fine for this I guess
pub fn floatRangeLessThan(comptime T: type, at_least: T, less_than: T) T {
    return at_least + getRand().float(T) * (less_than - at_least);
}
