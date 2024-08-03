const std = @import("std");
const Allocator = std.mem.Allocator;

const Ansi = @import("ansi.zig");
const Token = @import("token.zig").Token;
const Lexer = @import("lexer.zig").Lexer;
const Node = @import("node.zig").Node;
const Parser = @import("parser.zig").Parser;

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

        // try stdout.print("{s}\n", .{line});
        //var lexer = Lexer.init(line);
        //scan: while (true) {
        //    var token = lexer.next() catch {
        //        break :scan;
        //    };
        //    token.showInSource(line, Ansi.Cyan);
        //    if (token.matchTag(Token.Tag.EndOfFile)) {
        //        break :scan;
        //    }
        //}

        var parser = Parser.init(allocator, line);
        var node = parser.parse() catch {
            continue :repl;
        };
        defer node.free(allocator);
        node.debug(line);
    }
}
