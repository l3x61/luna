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
            if (self.char() == '*') {
                self.advance();
                return Token.init(.StarStar, self.cursor - 2, 2);
            }
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

        if (c == '.') {
            self.advance();
            if (!self.isEndOfFile() and self.char() == '.') {
                self.advance();
                return Token.init(.DotDot, self.cursor - 2, 2);
            }
            return Token.init(.Dot, self.cursor - 1, 1);
        }

        if (c == '|') {
            self.advance();
            if (!self.isEndOfFile() and self.char() == '|') {
                self.advance();
                return Token.init(.PipePipe, self.cursor - 2, 2);
            }
            return Token.init(.Pipe, self.cursor - 1, 1);
        }

        if (c == '&') {
            self.advance();
            if (!self.isEndOfFile() and self.char() == '&') {
                self.advance();
                return Token.init(.AndAnd, self.cursor - 2, 2);
            }
            return Token.init(.And, self.cursor - 1, 1);
        }

        if (c == '!') {
            self.advance();
            if (!self.isEndOfFile() and self.char() == '=') {
                self.advance();
                return Token.init(.BangEqual, self.cursor - 2, 2);
            }
            return Token.init(.Bang, self.cursor - 1, 1);
        }

        if (c == '<') {
            self.advance();
            if (!self.isEndOfFile() and self.char() == '=') {
                self.advance();
                return Token.init(.LessEqual, self.cursor - 2, 2);
            }
            return Token.init(.Less, self.cursor - 1, 1);
        }

        if (c == '>') {
            self.advance();
            if (!self.isEndOfFile() and self.char() == '=') {
                self.advance();
                return Token.init(.GreaterEqual, self.cursor - 2, 2);
            }
            return Token.init(.Greater, self.cursor - 1, 1);
        }

        if (c == '=') {
            self.advance();
            if (!self.isEndOfFile() and self.char() == '=') {
                self.advance();
                return Token.init(.EqualEqual, self.cursor - 2, 2);
            }
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

        if (c == '{') {
            self.advance();
            return Token.init(.LeftBrace, self.cursor - 1, 1);
        }

        if (c == '}') {
            self.advance();
            return Token.init(.RightBrace, self.cursor - 1, 1);
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
            if (std.mem.eql(u8, "null", self.source[start..self.cursor])) {
                return Token.init(.KeywordNull, start, self.cursor - start);
            } else if (std.mem.eql(u8, "true", self.source[start..self.cursor])) {
                return Token.init(.KeywordTrue, start, self.cursor - start);
            } else if (std.mem.eql(u8, "false", self.source[start..self.cursor])) {
                return Token.init(.KeywordFalse, start, self.cursor - start);
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
                    return Token.init(.ErrorStringNewline, start, self.cursor - start);
                }
                self.advance();
            }
            if (self.isEndOfFile()) {
                return Token.init(.ErrorStringOpen, start, self.cursor - start);
            }
            self.advance();
            return Token.init(.String, start, self.cursor - start);
        }
        return Token.init(.ErrorCharacter, self.cursor, 1);
    }
};
