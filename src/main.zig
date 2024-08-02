const std = @import("std");
const Ansi = @import("ansi.zig");
const Token = @import("token.zig").Token;
const Lexer = @import("lexer.zig").Lexer;

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

        // try stdout.print("{s}\n", .{line});
        var lexer = Lexer.init(line);
        scan: while (true) {
            var token = lexer.next() catch {
                break :scan;
            };
            token.showInSource(line, Ansi.Cyan);
            if (token.matchTag(Token.Tag.EndOfFile)) {
                break :scan;
            }
        }
    }
}
