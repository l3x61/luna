const std = @import("std");
const Allocator = std.mem.Allocator;

const Ansi = @import("ansi.zig");
const Token = @import("token.zig").Token;
const Lexer = @import("lexer.zig").Lexer;
const Node = @import("node.zig").Node;

pub const Parser = struct {
    allocator: Allocator,
    lexer: Lexer,
    token: Token,

    pub const Error = error{
        SyntaxError,
    };

    pub fn init(allocator: Allocator, source: []const u8) Parser {
        var lexer = Lexer.init(source);
        const token = lexer.next();
        return Parser{ .allocator = allocator, .lexer = lexer, .token = token };
    }

    pub fn parse(self: *Parser) !*Node {
        const node = try Node.initProgramNode(self.allocator);
        errdefer node.free(self.allocator);
        while (self.token.tag != Token.Tag.EndOfFile) {
            try node.as.program.statements.append(try self.parseStatement());
        }
        return node;
    }

    fn parseStatement(self: *Parser) !*Node {
        switch (self.token.tag) {
            else => return try self.parseExpression(),
        }
    }

    fn parseExpression(self: *Parser) !*Node {
        return self.parseAdditiveExpression();
    }

    fn parseAdditiveExpression(self: *Parser) !*Node {
        var node = try self.parseMultiplicativeExpression();
        errdefer node.free(self.allocator);
        while (self.token.matchTags(AdditiveTokenTags)) {
            const operator = try self.eatTags(AdditiveTokenTags);
            const right = try self.parseMultiplicativeExpression();
            errdefer right.free(self.allocator);
            node = try Node.initBinaryNode(self.allocator, node, operator, right);
        }
        return node;
    }

    fn parseMultiplicativeExpression(self: *Parser) !*Node {
        var node = try self.parsePowerExpression();
        errdefer node.free(self.allocator);
        while (self.token.matchTags(MultiplicativeTokenTags)) {
            const operator = try self.eatTags(MultiplicativeTokenTags);
            const right = try self.parsePowerExpression();
            errdefer right.free(self.allocator);
            node = try Node.initBinaryNode(self.allocator, node, operator, right);
        }
        return node;
    }

    fn parsePowerExpression(self: *Parser) !*Node {
        var node = try self.parseUnaryExpression();
        errdefer node.free(self.allocator);
        if (self.token.matchTag(.StarStar)) {
            const left = node;
            const operator = try self.eatTag(.StarStar);
            const right = try self.parsePowerExpression();
            errdefer right.free(self.allocator);
            node = try Node.initBinaryNode(self.allocator, left, operator, right);
        }
        return node;
    }

    fn parseUnaryExpression(self: *Parser) !*Node {
        if (self.token.matchTags(UnaryTokenTags)) {
            const operator = try self.eatTags(UnaryTokenTags);
            const operand = try self.parseUnaryExpression();
            errdefer operand.free(self.allocator);
            return try Node.initUnaryNode(self.allocator, operator, operand);
        } else {
            return self.parsePrimaryExpression();
        }
    }

    fn parsePrimaryExpression(self: *Parser) !*Node {
        const operand = try self.eatTags(PrimaryTokenTags);
        return try Node.initPrimaryNode(self.allocator, operand);
    }

    fn eatTag(self: *Parser, expected: Token.Tag) Parser.Error!Token {
        return self.eatTags(&[_]Token.Tag{expected});
    }

    fn eatTags(self: *Parser, expected: []const Token.Tag) Parser.Error!Token {
        const token = self.token;
        self.token = self.lexer.next();
        if (token.matchTags(expected)) {
            return token;
        } else {
            std.debug.print(Ansi.Red ++ "error" ++ Ansi.Reset ++ " unexpected token: {s}\n", .{token.tag.toString()});
            token.showInSource(self.lexer.source, Ansi.Red);
            return Error.SyntaxError;
        }
    }

    const AdditiveTokenTags = &[_]Token.Tag{
        .Plus,
        .Minus,
    };

    const MultiplicativeTokenTags = &[_]Token.Tag{
        .Star,
        .Slash,
        .Percent,
    };

    const UnaryTokenTags = &[_]Token.Tag{
        .Plus,
        .Minus,
    };

    const PrimaryTokenTags = &[_]Token.Tag{
        .Identifier,
        .Number,
        .String,
    };
};
