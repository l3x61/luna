const std = @import("std");
const Allocator = std.mem.Allocator;

const builtin = @import("builtin");
const Ansi = @import("ansi.zig");
const Token = @import("token.zig").Token;
const Lexer = @import("lexer.zig").Lexer;
const Node = @import("node.zig").Node;
const Parser = @import("parser.zig").Parser;
const Value = @import("value.zig").Value;
const Chunk = @import("chunk.zig").Chunk;
const Vm = @import("vm.zig").Vm;
const Table = @import("table.zig").Table;

const SipHash = @import("siphash.zig");

pub const Luna = struct {
    allocator: Allocator,
    globals: Table,

    pub fn init(allocator: Allocator) Luna {
        SipHash.randomKey();
        return Luna{
            .allocator = allocator,
            .globals = Table.init(allocator),
        };
    }

    pub fn deinit(self: *Luna) void {
        for (self.globals.entries) |*entry| {
            if (entry.key) |*key| key.deinit();
            if (entry.value) |*value| value.deinit();
        }
        self.globals.deinit();
    }

    pub fn repl(self: *Luna) !void {
        const stdin = std.io.getStdIn().reader();
        const stdout = std.io.getStdOut().writer();

        loop: while (true) {
            try stdout.print("> ", .{});

            var buffer: [1024]u8 = undefined;
            var line = try stdin.readUntilDelimiter(&buffer, '\n');
            if (builtin.os.tag == .windows and line[line.len - 1] == '\r') line.len -= 1;
            if (line.len == 0) continue :loop;
            if (std.mem.eql(u8, line, "exit")) break :loop;

            var parser = Parser.init(self.allocator, line);
            var ast = parser.parse() catch continue :loop;
            defer ast.free(self.allocator);
            try ast.debug(self.allocator, line);

            var chunk = Chunk.init(self.allocator);
            defer chunk.deinit();
            try chunk.compile(ast, line);
            chunk.debug();

            var vm = try Vm.init(self.allocator, chunk, &self.globals);
            defer vm.deinit();
            var timer = try std.time.Timer.start();
            try vm.run();
            const elapsed = @as(f64, @floatFromInt(timer.read()));
            vm.debugStack();
            vm.globals.debug();
            try stdout.print("Took: " ++ Ansi.Green ++ "{d:.3}" ++ Ansi.Bold ++ "ms\n" ++ Ansi.Reset, .{elapsed / std.time.ns_per_ms});
        }
    }
};
