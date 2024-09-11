const std = @import("std");
const Allocator = std.mem.Allocator;

const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("stdlib.h");
    @cInclude("readline/readline.h");
    @cInclude("readline/history.h");
});

pub fn cloneSlice(allocator: Allocator, comptime T: type, slice: []T) ![]T {
    const new = try allocator.alloc(T, slice.len);
    @memcpy(new, slice);
    return new;
}

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

pub fn readLine(allocator: Allocator, prompt: []const u8) ![]u8 {
    const line = c.readline(prompt.ptr);
    c.add_history(line);
    if (line == null) return cloneSlice(allocator, u8, "");
    defer c.free(line);
    return cloneSlice(allocator, u8, std.mem.span(line));
}
