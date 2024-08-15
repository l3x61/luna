const std = @import("std");
const Allocator = std.mem.Allocator;

const Ansi = @import("ansi.zig");
const Token = @import("token.zig").Token;
const Lexer = @import("lexer.zig").Lexer;
const Node = @import("node.zig").Node;
const Parser = @import("parser.zig").Parser;
const Value = @import("value.zig").Value;
const Chunk = @import("chunk.zig").Chunk;
const Vm = @import("vm.zig").Vm;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) {
        std.debug.print("MEMORY LEAK", .{});
    };
    const allocator = gpa.allocator();

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
        var timer = try std.time.Timer.start();
        var parser = Parser.init(allocator, line);
        var ast = parser.parse() catch {
            continue :repl;
        };
        defer ast.free(allocator);
        try ast.debug(allocator, line);

        var chunk = Chunk.init(allocator);
        defer chunk.deinit();
        try chunk.compile(ast, line);
        chunk.debug();

        var vm = try Vm.init(allocator, chunk);
        defer vm.deinit();
        try vm.run();
        const elapsed = @as(f64, @floatFromInt(timer.read()));
        vm.printTop();
        try stdout.print("Elapsed: {d}ms\n", .{elapsed / std.time.ns_per_ms});
    }
}
