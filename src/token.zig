const std = @import("std");
const Ansi = @import("ansi.zig");

pub const Token = struct {
    tag: Tag,
    start: usize,
    length: usize,

    pub const Tag = enum {
        Number,
        String,
        Identifier,
        Plus,
        Minus,
        Star,
        StarStar,
        Slash,
        Percent,
        Equal,
        LeftParenthesis,
        RightParenthesis,
        LeftBrace,
        RightBrace,
        ErrorStringNewline,
        ErrorStringOpen,
        ErrorCharacter,
        EndOfFile,

        pub fn format(self: Tag, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
            _ = fmt;
            _ = options;
            try writer.print("{s}", .{@tagName(self)});
        }
    };

    pub fn init(tag: Tag, start: usize, length: usize) Token {
        return Token{ .tag = tag, .start = start, .length = length };
    }

    pub fn lexeme(self: Token, source: []const u8) []const u8 {
        return source[self.start .. self.start + self.length];
    }

    pub fn matchTag(self: Token, tag: Tag) bool {
        return self.tag == tag;
    }

    pub fn matchTags(self: Token, tags: []const Tag) bool {
        for (tags) |kind| {
            if (self.matchTag(kind)) {
                return true;
            }
        }
        return false;
    }

    pub fn showInSource(self: Token, source: []const u8, color: []const u8) void {
        var cursor: usize = 0;
        var lineStart: usize = 0;
        var line: usize = 1;
        while (cursor < self.start) {
            if (source[cursor] == '\n') {
                line += 1;
                lineStart = cursor + 1;
            }
            cursor += 1;
        }

        var lineEnd = self.start;
        while (lineEnd < source.len and source[lineEnd] != '\n') {
            lineEnd += 1;
        }
        const before = source[lineStart..self.start];
        const token = source[self.start .. self.start + self.length];
        const after = source[self.start + self.length .. lineEnd];
        std.debug.print(Ansi.Yellow ++ "{d: >4}" ++ Ansi.Reset ++ " | {s}{s}{s}" ++ Ansi.Reset ++ "{s}\n", .{ line, before, color, token, after });
        std.debug.print(Ansi.Yellow ++ "{[e]s: >4}" ++ Ansi.Reset ++ " | {[e]s: >[before]}{[color]s}{[e]s:~>[token]}" ++ Ansi.Reset ++ "{[e]s: >[after]}\n", .{ .e = "", .before = before.len, .token = if (token.len == 0) 1 else token.len, .after = after.len, .color = color });
    }
};

test "show in source" {
    const source = "test'Hello World'test";
    const token = Token.init(Token.Tag.String, 4, 13);
    token.showInSource(source, Ansi.Magenta);
}
