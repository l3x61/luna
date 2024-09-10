const std = @import("std");
const Allocator = std.mem.Allocator;

const Luna = @import("luna.zig").Luna;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var luna = Luna.init(gpa.allocator());
    defer luna.deinit();
    try luna.repl();
}
