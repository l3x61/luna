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
        const token = lexer.nextToken();
        return Parser{ .allocator = allocator, .lexer = lexer, .token = token };
    }

    pub fn parse(self: *Parser) !*Node {
        return self.parseProgram();
    }

    pub fn parseProgram(self: *Parser) !*Node {
        const node = try Node.initProgramNode(self.allocator);
        errdefer node.deinit(self.allocator);
        while (self.token.tag != Token.Tag.EndOfFile) try node.as.program.statements.push(try self.parseStatement());
        return node;
    }

    fn parseStatement(self: *Parser) anyerror!*Node {
        switch (self.token.tag) {
            .KeywordLet => return try self.parseVariableDeclaration(),
            .LeftBrace => return try self.parseBlock(),
            else => return try self.parseExpression(),
        }
    }

    pub fn parseVariableDeclaration(self: *Parser) !*Node {
        _ = try self.eatToken(.KeywordLet);
        const name = try self.eatToken(.Identifier);
        var value: ?*Node = null;
        if (self.token.tag == .Equal) {
            _ = try self.eatToken(.Equal);
            value = try self.parseExpression();
        }
        return Node.initVariableDeclarationNode(self.allocator, name, value);
    }

    pub fn parseBlock(self: *Parser) !*Node {
        const node = try Node.initBlockNode(self.allocator);
        errdefer node.deinit(self.allocator);
        _ = try self.eatToken(.LeftBrace);
        while (self.token.tag != Token.Tag.RightBrace) try node.as.block.statements.push(try self.parseStatement());
        _ = try self.eatToken(.RightBrace);
        return node;
    }

    fn parseExpression(self: *Parser) !*Node {
        return try self.parseAssignmentExpression();
    }

    fn parseAssignmentExpression(self: *Parser) !*Node {
        var node = try self.parseLogicalOrExpression();
        errdefer node.deinit(self.allocator);
        if (self.token.matchTag(.Equal)) {
            const left = node;
            const operator = try self.eatToken(.Equal);
            const right = try self.parseAssignmentExpression();
            errdefer right.deinit(self.allocator);
            node = try Node.initBinaryNode(self.allocator, left, operator, right);
        }
        return node;
    }

    fn parseLogicalOrExpression(self: *Parser) !*Node {
        var node = try self.parseLogicalAndExpression();
        errdefer node.deinit(self.allocator);
        while (self.token.matchTag(.PipePipe)) {
            const operator = try self.eatToken(.PipePipe);
            const right = try self.parseLogicalAndExpression();
            errdefer right.deinit(self.allocator);
            node = try Node.initBinaryNode(self.allocator, node, operator, right);
        }
        return node;
    }

    fn parseLogicalAndExpression(self: *Parser) !*Node {
        var node = try self.parseEqualityExpression();
        errdefer node.deinit(self.allocator);
        while (self.token.matchTag(.AndAnd)) {
            const operator = try self.eatToken(.AndAnd);
            const right = try self.parseEqualityExpression();
            errdefer right.deinit(self.allocator);
            node = try Node.initBinaryNode(self.allocator, node, operator, right);
        }
        return node;
    }

    fn parseEqualityExpression(self: *Parser) !*Node {
        var node = try self.parseRelationalExpression();
        errdefer node.deinit(self.allocator);
        while (self.token.matchTags(EqualityTokenTags)) {
            const operator = try self.eatTokens(EqualityTokenTags);
            const right = try self.parseRelationalExpression();
            errdefer right.deinit(self.allocator);
            node = try Node.initBinaryNode(self.allocator, node, operator, right);
        }
        return node;
    }

    fn parseRelationalExpression(self: *Parser) !*Node {
        var node = try self.parseConcatenativeExpression();
        errdefer node.deinit(self.allocator);
        while (self.token.matchTags(RelationalTokenTags)) {
            const operator = try self.eatTokens(RelationalTokenTags);
            const right = try self.parseConcatenativeExpression();
            errdefer right.deinit(self.allocator);
            node = try Node.initBinaryNode(self.allocator, node, operator, right);
        }
        return node;
    }

    fn parseConcatenativeExpression(self: *Parser) !*Node {
        var node = try self.parseAdditiveExpression();
        errdefer node.deinit(self.allocator);
        while (self.token.matchTag(.DotDot)) {
            const operator = try self.eatToken(.DotDot);
            const right = try self.parseAdditiveExpression();
            errdefer right.deinit(self.allocator);
            node = try Node.initBinaryNode(self.allocator, node, operator, right);
        }
        return node;
    }

    fn parseAdditiveExpression(self: *Parser) !*Node {
        var node = try self.parseMultiplicativeExpression();
        errdefer node.deinit(self.allocator);
        while (self.token.matchTags(AdditiveTokenTags)) {
            const operator = try self.eatTokens(AdditiveTokenTags);
            const right = try self.parseMultiplicativeExpression();
            errdefer right.deinit(self.allocator);
            node = try Node.initBinaryNode(self.allocator, node, operator, right);
        }
        return node;
    }

    fn parseMultiplicativeExpression(self: *Parser) !*Node {
        var node = try self.parsePowerExpression();
        errdefer node.deinit(self.allocator);
        while (self.token.matchTags(MultiplicativeTokenTags)) {
            const operator = try self.eatTokens(MultiplicativeTokenTags);
            const right = try self.parsePowerExpression();
            errdefer right.deinit(self.allocator);
            node = try Node.initBinaryNode(self.allocator, node, operator, right);
        }
        return node;
    }

    fn parsePowerExpression(self: *Parser) !*Node {
        var node = try self.parseUnaryExpression();
        errdefer node.deinit(self.allocator);
        if (self.token.matchTag(.StarStar)) {
            const left = node;
            const operator = try self.eatToken(.StarStar);
            const right = try self.parsePowerExpression();
            errdefer right.deinit(self.allocator);
            node = try Node.initBinaryNode(self.allocator, left, operator, right);
        }
        return node;
    }

    fn parseUnaryExpression(self: *Parser) !*Node {
        if (self.token.matchTags(UnaryTokenTags)) {
            const operator = try self.eatTokens(UnaryTokenTags);
            const operand = try self.parsePrimaryExpression();
            errdefer operand.deinit(self.allocator);
            return Node.initUnaryNode(self.allocator, operator, operand);
        }
        return self.parsePrimaryExpression();
    }

    fn parsePrimaryExpression(self: *Parser) !*Node {
        switch (self.token.tag) {
            .LeftParenthesis => return try self.parseGroupingExpression(),
            else => {
                const operand = try self.eatTokens(PrimaryTokenTags);
                return try Node.initPrimaryNode(self.allocator, operand);
            },
        }
    }

    fn parseGroupingExpression(self: *Parser) anyerror!*Node {
        _ = try self.eatToken(.LeftParenthesis);
        const node = try self.parseExpression();
        _ = try self.eatToken(.RightParenthesis);
        return node;
    }

    fn eatToken(self: *Parser, expected: Token.Tag) !Token {
        return self.eatTokens(&[_]Token.Tag{expected});
    }

    fn eatTokens(self: *Parser, expected: []const Token.Tag) !Token {
        const token = self.token;
        self.token = self.lexer.nextToken();
        if (token.matchTags(expected)) {
            return token;
        } else {
            std.debug.print(Ansi.Red ++ "error" ++ Ansi.Reset ++ " unexpected token: " ++ Ansi.Red ++ "{}" ++ Ansi.Reset ++ " expected " ++ Ansi.Green, .{token.tag});
            switch (expected.len) {
                0 => unreachable,
                1 => std.debug.print("{}", .{expected[0]}),
                2 => std.debug.print("{}" ++ Ansi.Reset ++ " or " ++ Ansi.Green ++ "{}", .{ expected[0], expected[1] }),
                else => {
                    for (expected[0 .. expected.len - 2]) |tag| std.debug.print("{}, ", .{tag});
                    std.debug.print("{}" ++ Ansi.Reset ++ " or " ++ Ansi.Green ++ "{}", .{ expected[expected.len - 2], expected[expected.len - 1] });
                },
            }
            std.debug.print("\n" ++ Ansi.Reset, .{});
            token.showInSource(Ansi.Red);
            return Error.SyntaxError;
        }
    }

    // vvvv TODO: use a LUT ?

    const EqualityTokenTags = &[_]Token.Tag{
        .EqualEqual,
        .BangEqual,
    };

    const RelationalTokenTags = &[_]Token.Tag{
        .Less,
        .LessEqual,
        .Greater,
        .GreaterEqual,
    };

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
        .Bang,
        .Minus,
        .Plus,
    };

    const PrimaryTokenTags = &[_]Token.Tag{
        .KeywordNull,
        .KeywordTrue,
        .KeywordFalse,
        .Number,
        .String,
        .Identifier,
    };

    // ^^^^ TODO: use a LUT ?
};
