const std = @import("std");

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    repl: while (true) {
        try stdout.print("> ", .{});
        var buffer: [1024]u8 = undefined;
        const line = try stdin.readUntilDelimiter(&buffer, '\n');
        if (line.len == 0) {
            continue :repl;
        }
        if (std.mem.eql(u8, line, "exit")) {
            break :repl;
        }

        try stdout.print("{s}\n", .{line});
    }
}
