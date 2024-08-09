const std = @import("std");

pub fn nextPowerOf2(n: usize) usize {
    comptime std.debug.assert(@sizeOf(usize) == 8);
    var result: usize = n;
    result |= result >> 1;
    result |= result >> 2;
    result |= result >> 4;
    result |= result >> 8;
    result |= result >> 16;
    result |= result >> 32;
    result += 1;
    return result;
}
