const std = @import("std");
const Ansi = @import("ansi.zig");

pub const Token = struct {
    tag: Tag,
    source: []const u8,
    lexeme: []const u8,

    pub const Tag = enum {
        Number,
        String,
        Identifier,
        KeywordNull,
        KeywordTrue,
        KeywordFalse,
        Plus,
        Minus,
        Star,
        StarStar,
        Slash,
        Percent,
        Dot,
        DotDot,
        Pipe,
        PipePipe,
        And,
        AndAnd,
        Bang,
        BangEqual,
        Less,
        LessEqual,
        Greater,
        GreaterEqual,
        Equal,
        EqualEqual,
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

    pub fn init(tag: Tag, source: []const u8, lexeme: []const u8) Token {
        return Token{ .tag = tag, .source = source, .lexeme = lexeme };
    }

    pub fn stringLiteral(self: Token) []const u8 {
        return self.lexeme[1 .. self.lexeme.len - 1];
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

    pub fn showInSource(self: Token, color: []const u8) void {
        var cursor: usize = 0;
        var line_start: usize = 0;
        var line: usize = 1;
        const start_index = @intFromPtr(self.lexeme.ptr) - @intFromPtr(self.source.ptr);
        while (cursor < start_index) {
            if (self.source[cursor] == '\n') {
                line += 1;
                line_start = cursor + 1;
            }
            cursor += 1;
        }
        var line_end = start_index;
        while (line_end < self.source.len and self.source[line_end] != '\n') line_end += 1;
        const before_lexeme = self.source[line_start..start_index];
        const after_lexeme = self.source[start_index + self.lexeme.len .. line_end];
        std.debug.print(Ansi.Yellow ++ "{d: >4}" ++ Ansi.Reset ++ " | {s}{s}{s}" ++ Ansi.Reset ++ "{s}\n", .{ line, before_lexeme, color, self.lexeme, after_lexeme });
        std.debug.print(Ansi.Yellow ++ "{[e]s: >4}" ++ Ansi.Reset ++ " | {[e]s: >[before]}{[color]s}{[e]s:~>[token]}" ++ Ansi.Reset ++ "{[e]s: >[after]}\n", .{ .e = "", .before = before_lexeme.len, .token = if (self.lexeme.len == 0) 1 else self.lexeme.len, .after = after_lexeme.len, .color = color });
    }
};

test "show in source" {
    const source = "test'Hello World'test";
    const token = Token.init(Token.Tag.String, source, source[4..13]);
    token.showInSource(Ansi.Magenta);
}
