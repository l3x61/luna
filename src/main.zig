const std = @import("std");
const Allocator = std.mem.Allocator;

const Luna = @import("luna.zig").Luna;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) {
        std.debug.print("MEMORY LEAK", .{});
    };
    const allocator = gpa.allocator();

    var luna = Luna.init(allocator);
    defer luna.deinit();
    try luna.repl();
}
