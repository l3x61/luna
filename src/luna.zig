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

    pub fn runSource(self: *Luna, source: []const u8) !Value {
        var parser = Parser.init(self.allocator, source);
        var ast = try parser.parse();
        defer ast.free(self.allocator);

        var chunk = Chunk.init(self.allocator);
        defer chunk.deinit();
        try chunk.compile(ast);

        var vm = try Vm.init(self.allocator, chunk, &self.globals);
        defer vm.deinit();
        try vm.run();

        var result = vm.stack.peek() orelse return Value.initNull();
        return result.clone();
    }

    pub fn repl(self: *Luna) !void {
        const stdin = std.io.getStdIn().reader();
        const stdout = std.io.getStdOut().writer();

        loop: while (true) {
            try stdout.print("> ", .{});

            var buffer: [1024]u8 = undefined;
            var line = try stdin.readUntilDelimiter(&buffer, '\n');
            if (builtin.os.tag == .windows and line[line.len - 1] == '\r') line.len -= 1;
            //if (line.len == 0) continue :loop;
            if (std.mem.eql(u8, line, "exit")) break :loop;

            var parser = Parser.init(self.allocator, line);
            var ast = parser.parse() catch continue :loop;
            defer ast.free(self.allocator);
            try ast.debug(self.allocator);

            var chunk = Chunk.init(self.allocator);
            defer chunk.deinit();
            try chunk.compile(ast);
            chunk.debug();

            var vm = try Vm.init(self.allocator, chunk, &self.globals);
            defer vm.deinit();
            var timer = try std.time.Timer.start();
            try vm.run();
            const elapsed: f64 = @floatFromInt(timer.read());
            vm.debugStack();
            vm.globals.debug();
            try stdout.print(Ansi.Green ++ "{d:.3}" ++ Ansi.Bold ++ "ms\n" ++ Ansi.Reset, .{elapsed / std.time.ns_per_ms});
        }
    }
};

fn testWrapper(allocator: Allocator, test_name: []const u8, source: []const u8, expected: Value) !bool {
    var luna = Luna.init(allocator);
    defer luna.deinit();

    var timer = try std.time.Timer.start();
    var result = try luna.runSource(source);
    defer result.deinit();
    const elapsed: f64 = @floatFromInt(timer.read());
    std.debug.print(Ansi.Cyan ++ "{s}" ++ Ansi.Reset ++ " took: " ++ Ansi.Green ++ "{d:.3}" ++ Ansi.Bold ++ "ms\n" ++ Ansi.Reset, .{ test_name, elapsed / std.time.ns_per_ms });
    return Value.compare(result, expected);
}

test "empty" {
    const source =
        \\
    ;
    var expect = Value.initNull();
    defer expect.deinit();
    try std.testing.expect(try testWrapper(std.testing.allocator, @src().fn_name[5..], source, expect));
}

test "free \"leaked\" string" {
    const source =
        \\a = "hello"
        \\a = "world"
        \\a = "!"
    ;
    var expect = try Value.initObjectStringLiteral(std.testing.allocator, "!");
    defer expect.deinit();
    try std.testing.expect(try testWrapper(std.testing.allocator, @src().fn_name[5..], source, expect));
}

test "random expression" {
    const source =
        \\1 + 2 *
        \\ 3 / 4 -
        \\5 **
        \\6 %
        \\7
    ;
    var expect = Value.initNumber(1.5);
    defer expect.deinit();
    try std.testing.expect(try testWrapper(std.testing.allocator, @src().fn_name[5..], source, expect));
}

test "chain assign" {
    const source =
        \\a = b = c = c = d = e = 1
        \\a = b = c = c = d = e = 'test'
        \\a = b = c = c = d = e = 1 + 2 * 3 / 4 - 5 ** 6 % 7
    ;
    var expect = Value.initNumber(1.5);
    defer expect.deinit();
    try std.testing.expect(try testWrapper(std.testing.allocator, @src().fn_name[5..], source, expect));
}

test "get global" {
    // global variables dont need an explicit declaration
    // they are created on the fly
    // reading a nonexistent global variable will return null
    const source =
        \\global_var
    ;
    var expect = Value.initNull();
    defer expect.deinit();
    try std.testing.expect(try testWrapper(std.testing.allocator, @src().fn_name[5..], source, expect));
}

test "set global in block" {
    // if the scope doesnt have a local variable with the same name
    // a global variable will be created
    const source =
        \\{ global_var = 1 }
        \\global_var
    ;
    var expect = Value.initNumber(1.0);
    defer expect.deinit();
    try std.testing.expect(try testWrapper(std.testing.allocator, @src().fn_name[5..], source, expect));
}

test "global variable declaration" {
    const source =
        \\let a = 123
        \\let b = "hello"
        \\a .. b
    ;
    var expect = try Value.initObjectStringLiteral(std.testing.allocator, "123hello");
    defer expect.deinit();
    try std.testing.expect(try testWrapper(std.testing.allocator, @src().fn_name[5..], source, expect));
}
