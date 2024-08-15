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

pub const Luna = struct {
    allocator: Allocator,

    pub fn init(allocator: Allocator) Luna {
        return Luna{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: Luna) void {
        _ = self.allocator;
    }

    pub fn repl(self: *Luna) !void {
        const stdin = std.io.getStdIn().reader();
        const stdout = std.io.getStdOut().writer();

        loop: while (true) {
            try stdout.print("> ", .{});
            var buffer: [1024]u8 = undefined;
            const line = try stdin.readUntilDelimiter(&buffer, '\n');
            if (line.len == 0) {
                continue :loop;
            }
            if (std.mem.eql(u8, line, "exit")) {
                break :loop;
            }
            var timer = try std.time.Timer.start();
            var parser = Parser.init(self.allocator, line);
            var ast = parser.parse() catch {
                continue :loop;
            };
            defer ast.free(self.allocator);
            try ast.debug(self.allocator, line);

            var chunk = Chunk.init(self.allocator);
            defer chunk.deinit();
            try chunk.compile(ast, line);
            chunk.debug();

            var vm = try Vm.init(self.allocator, chunk);
            defer vm.deinit();
            try vm.run();
            const elapsed = @as(f64, @floatFromInt(timer.read()));
            vm.printTop();
            try stdout.print("Elapsed: {d}ms\n", .{elapsed / std.time.ns_per_ms});
        }
    }
};
