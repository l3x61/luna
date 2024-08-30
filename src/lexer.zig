const std = @import("std");
const Ansi = @import("ansi.zig");
const Token = @import("token.zig").Token;

pub const Lexer = struct {
    source: []const u8,
    cursor: usize,

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

    pub fn next(self: *Lexer) Token {
        if (self.isEndOfFile()) {
            return Token.init(.EndOfFile, self.source, "");
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
            return Token.init(.Plus, self.source, self.source[self.cursor - 1 .. self.cursor]);
        }

        if (c == '-') {
            self.advance();
            return Token.init(.Minus, self.source, self.source[self.cursor - 1 .. self.cursor]);
        }

        if (c == '*') {
            self.advance();
            if (self.char() == '*') {
                self.advance();
                return Token.init(.StarStar, self.source, self.source[self.cursor - 2 .. self.cursor]);
            }
            return Token.init(.Star, self.source, self.source[self.cursor - 1 .. self.cursor]);
        }

        if (c == '/') {
            self.advance();
            return Token.init(.Slash, self.source, self.source[self.cursor - 1 .. self.cursor]);
        }

        if (c == '%') {
            self.advance();
            return Token.init(.Percent, self.source, self.source[self.cursor - 1 .. self.cursor]);
        }

        if (c == '.') {
            self.advance();
            if (!self.isEndOfFile() and self.char() == '.') {
                self.advance();
                return Token.init(.DotDot, self.source, self.source[self.cursor - 2 .. self.cursor]);
            }
            return Token.init(.Dot, self.source, self.source[self.cursor - 1 .. self.cursor]);
        }

        if (c == '|') {
            self.advance();
            if (!self.isEndOfFile() and self.char() == '|') {
                self.advance();
                return Token.init(.PipePipe, self.source, self.source[self.cursor - 2 .. self.cursor]);
            }
            return Token.init(.Pipe, self.source, self.source[self.cursor - 1 .. self.cursor]);
        }

        if (c == '&') {
            self.advance();
            if (!self.isEndOfFile() and self.char() == '&') {
                self.advance();
                return Token.init(.AndAnd, self.source, self.source[self.cursor - 2 .. self.cursor]);
            }
            return Token.init(.And, self.source, self.source[self.cursor - 1 .. self.cursor]);
        }

        if (c == '!') {
            self.advance();
            if (!self.isEndOfFile() and self.char() == '=') {
                self.advance();
                return Token.init(.BangEqual, self.source, self.source[self.cursor - 2 .. self.cursor]);
            }
            return Token.init(.Bang, self.source, self.source[self.cursor - 1 .. self.cursor]);
        }

        if (c == '<') {
            self.advance();
            if (!self.isEndOfFile() and self.char() == '=') {
                self.advance();
                return Token.init(.LessEqual, self.source, self.source[self.cursor - 2 .. self.cursor]);
            }
            return Token.init(.Less, self.source, self.source[self.cursor - 1 .. self.cursor]);
        }

        if (c == '>') {
            self.advance();
            if (!self.isEndOfFile() and self.char() == '=') {
                self.advance();
                return Token.init(.GreaterEqual, self.source, self.source[self.cursor - 2 .. self.cursor]);
            }
            return Token.init(.Greater, self.source, self.source[self.cursor - 1 .. self.cursor]);
        }

        if (c == '=') {
            self.advance();
            if (!self.isEndOfFile() and self.char() == '=') {
                self.advance();
                return Token.init(.EqualEqual, self.source, self.source[self.cursor - 2 .. self.cursor]);
            }
            return Token.init(.Equal, self.source, self.source[self.cursor - 1 .. self.cursor]);
        }

        if (c == '(') {
            self.advance();
            return Token.init(.LeftParenthesis, self.source, self.source[self.cursor - 1 .. self.cursor]);
        }

        if (c == ')') {
            self.advance();
            return Token.init(.RightParenthesis, self.source, self.source[self.cursor - 1 .. self.cursor]);
        }

        if (c == '{') {
            self.advance();
            return Token.init(.LeftBrace, self.source, self.source[self.cursor - 1 .. self.cursor]);
        }

        if (c == '}') {
            self.advance();
            return Token.init(.RightBrace, self.source, self.source[self.cursor - 1 .. self.cursor]);
        }

        if (self.isDigit()) {
            const start = self.cursor;
            while (!self.isEndOfFile() and self.isDigit()) {
                self.advance();
            }
            return Token.init(.Number, self.source, self.source[start..self.cursor]);
        }

        if (self.isAlpha()) {
            const start = self.cursor;
            while (!self.isEndOfFile() and (self.isAlpha() or self.isDigit())) {
                self.advance();
            }
            if (std.mem.eql(u8, "null", self.source[start..self.cursor])) {
                return Token.init(.KeywordNull, self.source, self.source[start..self.cursor]);
            } else if (std.mem.eql(u8, "true", self.source[start..self.cursor])) {
                return Token.init(.KeywordTrue, self.source, self.source[start..self.cursor]);
            } else if (std.mem.eql(u8, "false", self.source[start..self.cursor])) {
                return Token.init(.KeywordFalse, self.source, self.source[start..self.cursor]);
            }
            return Token.init(.Identifier, self.source, self.source[start..self.cursor]);
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
                    return Token.init(.ErrorStringNewline, self.source, self.source[start..self.cursor]);
                }
                self.advance();
            }
            if (self.isEndOfFile()) {
                return Token.init(.ErrorStringOpen, self.source, self.source[start..self.cursor]);
            }
            self.advance();
            return Token.init(.String, self.source, self.source[start..self.cursor]);
        }
        return Token.init(.ErrorCharacter, self.source, self.source[self.cursor .. self.cursor + 1]);
    }
};
