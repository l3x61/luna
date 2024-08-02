const std = @import("std");
const Ansi = @import("ansi.zig");
const Token = @import("token.zig").Token;

pub const Lexer = struct {
    source: []const u8,
    cursor: usize,

    // NOTE: maybe instead of throwing an error, return an error token and let the parser handle it
    pub const Error = error{
        NewlineInString,
        UnterminatedString,
        InvalidCharacter,
    };

    pub fn init(source: []const u8) Lexer {
        return Lexer{ .source = source, .cursor = 0 };
    }

    fn char(self: *Lexer) u8 {
        return self.source[self.cursor];
    }

    fn advance(self: *Lexer) void {
        self.cursor += 1;
    }

    fn isEndOfFile(self: *Lexer) bool {
        return self.cursor >= self.source.len;
    }

    fn isWhitespace(self: *Lexer) bool {
        const c = self.char();
        return c == ' ' or c == '\t' or c == '\n' or c == '\r';
    }

    fn skipWhitespace(self: *Lexer) void {
        while (!self.isEndOfFile() and self.isWhitespace()) {
            self.advance();
        }
    }

    fn isDigit(self: *Lexer) bool {
        const c = self.char();
        return c >= '0' and c <= '9';
    }

    fn isAlpha(self: *Lexer) bool {
        const c = self.char();
        return c >= 'a' and c <= 'z' or c >= 'A' and c <= 'Z' or c == '_';
    }

    pub fn next(self: *Lexer) Lexer.Error!Token {
        if (self.isEndOfFile()) {
            return Token.init(.EndOfFile, self.source.len, 0);
        }

        if (self.isWhitespace()) {
            self.skipWhitespace();
            return self.next();
        }

        const c = self.char();

        if (c == '#') {
            while (!self.isEndOfFile() and self.char() != '\n') {
                self.advance();
            }
            return self.next();
        }

        if (c == '+') {
            self.advance();
            return Token.init(.Plus, self.cursor - 1, 1);
        }

        if (c == '-') {
            self.advance();
            return Token.init(.Minus, self.cursor - 1, 1);
        }

        if (c == '*') {
            self.advance();
            return Token.init(.Star, self.cursor - 1, 1);
        }

        if (c == '/') {
            self.advance();
            return Token.init(.Slash, self.cursor - 1, 1);
        }

        if (c == '%') {
            self.advance();
            return Token.init(.Percent, self.cursor - 1, 1);
        }

        if (c == '=') {
            self.advance();
            return Token.init(.Equal, self.cursor - 1, 1);
        }

        if (c == '(') {
            self.advance();
            return Token.init(.LeftParenthesis, self.cursor - 1, 1);
        }

        if (c == ')') {
            self.advance();
            return Token.init(.RightParenthesis, self.cursor - 1, 1);
        }

        if (self.isDigit()) {
            const start = self.cursor;
            while (!self.isEndOfFile() and self.isDigit()) {
                self.advance();
            }
            return Token.init(.Number, start, self.cursor - start);
        }

        if (self.isAlpha()) {
            const start = self.cursor;
            while (!self.isEndOfFile() and (self.isAlpha() or self.isDigit())) {
                self.advance();
            }
            return Token.init(.Identifier, start, self.cursor - start);
        }

        if (c == '\'' or c == '"') {
            const start = self.cursor;
            const quote = c;
            self.advance();
            while (!self.isEndOfFile() and self.char() != quote) {
                if (self.char() == '\\') {
                    // TODO: escape sequence
                }
                if (self.char() == '\n') {
                    const token = Token.init(.String, start, self.cursor - start);
                    std.debug.print(Ansi.Red ++ "error" ++ Ansi.Reset ++ " newline in string\n", .{});
                    token.showInSource(self.source, Ansi.Red);
                    return Error.NewlineInString;
                }
                self.advance();
            }
            if (self.isEndOfFile()) {
                const token = Token.init(.String, start, self.cursor - start);
                std.debug.print(Ansi.Red ++ "error" ++ Ansi.Reset ++ " unterminated string\n", .{});
                token.showInSource(self.source, Ansi.Red);
                return Error.UnterminatedString;
            }
            self.advance();
            return Token.init(.String, start, self.cursor - start);
        }

        const token = Token.init(.Identifier, self.cursor, 1);
        std.debug.print(Ansi.Red ++ "error" ++ Ansi.Reset ++ " invalid character\n", .{});
        token.showInSource(self.source, Ansi.Red);
        return Error.InvalidCharacter;
    }
};

test "newline in string" {
    const source = "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n'hello\nworld!'";
    var lexer = Lexer.init(source);
    _ = lexer.next() catch |err| switch (err) {
        Lexer.Error.NewlineInString => {},
        else => unreachable,
    };
}

test "unterminated string" {
    const source = "\n\n\n\n\n\n'hello world!";
    var lexer = Lexer.init(source);
    _ = lexer.next() catch |err| switch (err) {
        Lexer.Error.UnterminatedString => {},
        else => unreachable,
    };
}

test "invalid character" {
    const source = "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n`";
    var lexer = Lexer.init(source);
    _ = lexer.next() catch |err| switch (err) {
        Lexer.Error.InvalidCharacter => {},
        else => unreachable,
    };
}
