const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const Ansi = @import("ansi.zig");
const Array = @import("array.zig").Array;
const String = @import("string.zig").String;
const Token = @import("token.zig").Token;

const ProgramNode = struct {
    statements: Array(*Node),
};

const BlockNode = struct {
    statements: Array(*Node),
};

const VariableDeclarationNode = struct {
    name: Token,
    value: ?*Node,
};

const ExpressionNode = union {
    expression: *Node,
};

const BinaryNode = struct {
    operator: Token,
    left: *Node,
    right: *Node,
};

const UnaryNode = struct {
    operator: Token,
    operand: *Node,
};

const PrimaryNode = struct {
    operand: Token,
};

pub const Node = struct {
    tag: Tag,
    as: Union,

    pub const Tag = enum {
        Program,
        Block,
        VariableDeclaration,
        Expression,
        Binary,
        Unary,
        Primary,

        pub fn toString(self: Tag) []const u8 {
            return @tagName(self);
        }
    };

    pub const Union = union {
        program: ProgramNode,
        block: BlockNode,
        variable_declaration: VariableDeclarationNode,
        expression: ExpressionNode,
        binary: BinaryNode,
        unary: UnaryNode,
        primary: PrimaryNode,
    };

    pub fn initProgramNode(allocator: Allocator) !*Node {
        var node = try allocator.create(Node);
        node.tag = Node.Tag.Program;
        node.as = Union{ .program = ProgramNode{ .statements = Array(*Node).init(allocator) } };
        return node;
    }

    pub fn initBlockNode(allocator: Allocator) !*Node {
        var node = try allocator.create(Node);
        node.tag = Node.Tag.Block;
        node.as = Union{ .block = BlockNode{ .statements = Array(*Node).init(allocator) } };
        return node;
    }

    pub fn initVariableDeclarationNode(allocator: Allocator, name: Token, value: ?*Node) !*Node {
        var node = try allocator.create(Node);
        node.tag = Node.Tag.VariableDeclaration;
        node.as = Union{ .variable_declaration = VariableDeclarationNode{ .name = name, .value = value } };
        return node;
    }

    pub fn initExpressionNode(allocator: Allocator, expression: *Node) !*Node {
        var node = try allocator.create(Node);
        node.tag = Node.Tag.Expression;
        node.as = Union{ .expression = ExpressionNode{ .expression = expression } };
        return node;
    }

    pub fn initBinaryNode(allocator: Allocator, left: *Node, operator: Token, right: *Node) !*Node {
        var node = try allocator.create(Node);
        node.tag = Node.Tag.Binary;
        node.as = Union{ .binary = BinaryNode{ .operator = operator, .left = left, .right = right } };
        return node;
    }

    pub fn initUnaryNode(allocator: Allocator, operator: Token, operand: *Node) !*Node {
        var node = try allocator.create(Node);
        node.tag = Node.Tag.Unary;
        node.as = Union{ .unary = UnaryNode{ .operator = operator, .operand = operand } };
        return node;
    }

    pub fn initPrimaryNode(allocator: Allocator, operand: Token) !*Node {
        var node = try allocator.create(Node);
        node.tag = Node.Tag.Primary;
        node.as = Union{ .primary = PrimaryNode{ .operand = operand } };
        return node;
    }

    pub fn deinit(self: *Node, allocator: Allocator) void {
        switch (self.tag) {
            .Program => {
                for (self.as.program.statements.items) |statement| statement.deinit(allocator);
                self.as.program.statements.deinit();
                allocator.destroy(self);
            },
            .Block => {
                for (self.as.block.statements.items) |statement| statement.deinit(allocator);
                self.as.block.statements.deinit();
                allocator.destroy(self);
            },
            .VariableDeclaration => {
                if (self.as.variable_declaration.value) |value| value.deinit(allocator);
                allocator.destroy(self);
            },
            .Expression => {
                self.as.expression.expression.deinit(allocator);
                allocator.destroy(self);
            },
            .Binary => {
                self.as.binary.left.deinit(allocator);
                self.as.binary.right.deinit(allocator);
                allocator.destroy(self);
            },
            .Unary => {
                self.as.unary.operand.deinit(allocator);
                allocator.destroy(self);
            },
            .Primary => {
                allocator.destroy(self);
            },
        }
    }

    pub fn debug(self: *Node, allocator: Allocator) !void {
        var prefix = String.init(allocator);
        defer prefix.deinit();
        try self.debugInternal(&prefix, true);
    }

    fn debugInternal(self: *Node, prefix: *String, is_last: bool) !void {
        std.debug.print(Ansi.Dim ++ "{s}", .{prefix.buffer});
        var _prefix = try prefix.clone();
        defer _prefix.deinit();
        if (!is_last) {
            std.debug.print("├── ", .{});
            try _prefix.appendLiteral("│   ");
        } else {
            if (self.tag != Node.Tag.Program) {
                std.debug.print("└── ", .{});
                try _prefix.appendLiteral("    ");
            }
        }
        std.debug.print(Ansi.Reset, .{});

        switch (self.tag) {
            .Program => {
                std.debug.print("Program\n", .{});
                for (self.as.program.statements.items, 0..) |statement, index| {
                    const is_last_statement = index == self.as.program.statements.count() - 1;
                    try statement.debugInternal(&_prefix, is_last_statement);
                }
            },
            .Block => {
                std.debug.print("Block\n", .{});
                for (self.as.block.statements.items, 0..) |statement, index| {
                    const is_last_statement = index == self.as.block.statements.count() - 1;
                    try statement.debugInternal(&_prefix, is_last_statement);
                }
            },
            .VariableDeclaration => {
                std.debug.print("VariableDeclaration " ++ Ansi.Magenta ++ "{s}\n" ++ Ansi.Reset, .{self.as.variable_declaration.name.lexeme});
                if (self.as.variable_declaration.value) |value| try value.debugInternal(&_prefix, true);
            },
            .Expression => {
                std.debug.print("Expression\n", .{});
                try self.as.expression.expression.debugInternal(&_prefix, true);
            },
            .Binary => {
                std.debug.print("Binary " ++ Ansi.Magenta ++ "{s}\n" ++ Ansi.Reset, .{self.as.binary.operator.lexeme});
                try self.as.binary.left.debugInternal(&_prefix, false);
                try self.as.binary.right.debugInternal(&_prefix, true);
            },
            .Unary => {
                std.debug.print("Unary " ++ Ansi.Magenta ++ "{s}\n" ++ Ansi.Reset, .{self.as.unary.operator.lexeme});
                try self.as.unary.operand.debugInternal(&_prefix, true);
            },
            .Primary => {
                const operand = self.as.primary.operand;
                std.debug.print("{} " ++ Ansi.Cyan ++ "{s}\n" ++ Ansi.Reset, .{ operand.tag, operand.lexeme });
            },
        }
    }
};
