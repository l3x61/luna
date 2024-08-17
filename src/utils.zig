const std = @import("std");

pub fn isPowerOf2(u: usize) bool {
    return u != 0 and (u & (u - 1)) == 0;
}

pub fn nextPowerOf2(u: usize) usize {
    comptime std.debug.assert(@sizeOf(usize) == 8);
    var result: usize = u;
    result |= result >> 1;
    result |= result >> 2;
    result |= result >> 4;
    result |= result >> 8;
    result |= result >> 16;
    result |= result >> 32;
    result += 1;
    return result;
}
