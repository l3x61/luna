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
    const Tag = enum {
        Program,
        Binary,
        Unary,
        Primary,

        pub fn toString(self: Tag) []const u8 {
            return @tagName(self);
        }
    };

    tag: Tag,
    as: Union,

    const Union = union {
        program: ProgramNode,
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

    pub fn free(self: *Node, allocator: Allocator) void {
        switch (self.tag) {
            .Program => {
                for (self.as.program.statements.items) |statement| {
                    statement.free(allocator);
                }
                self.as.program.statements.deinit();
                allocator.destroy(self);
            },
            .Binary => {
                self.as.binary.left.free(allocator);
                self.as.binary.right.free(allocator);
                allocator.destroy(self);
            },
            .Unary => {
                self.as.unary.operand.free(allocator);
                allocator.destroy(self);
            },
            .Primary => {
                allocator.destroy(self);
            },
        }
    }

    pub fn debug(self: *Node, allocator: Allocator, source: []const u8) !void {
        var buffer = String.init(allocator);
        defer buffer.deinit();
        try self.debugInternal(&buffer, source, true);
    }

    fn debugInternal(self: *Node, prefix: *String, source: []const u8, isLast: bool) !void {
        std.debug.print(Ansi.Dim ++ "{s}", .{prefix.items});
        var _prefix = try prefix.clone();
        defer _prefix.deinit();
        if (!isLast) {
            std.debug.print("├── ", .{});
            try _prefix.append("│   ");
        } else {
            if (self.tag != Node.Tag.Program) {
                std.debug.print("└── ", .{});
                try _prefix.append("    ");
            }
        }
        std.debug.print(Ansi.Reset, .{});

        // Print the node type and recurse into children
        switch (self.tag) {
            .Program => {
                std.debug.print("Program\n", .{});
                for (self.as.program.statements.items, 0..) |statement, index| {
                    const isLastStatement = index == self.as.program.statements.items.len - 1;
                    try statement.debugInternal(&_prefix, source, isLastStatement);
                }
            },
            .Binary => {
                std.debug.print("BinaryExpression {[operator]s}\n", .{ .operator = self.as.binary.operator.lexeme(source) });
                try self.as.binary.left.debugInternal(&_prefix, source, false);
                try self.as.binary.right.debugInternal(&_prefix, source, true);
            },
            .Unary => {
                std.debug.print("UnaryExpression {[operator]s}\n", .{ .operator = self.as.unary.operator.lexeme(source) });
                try self.as.unary.operand.debugInternal(&_prefix, source, true);
            },
            .Primary => {
                const operand = self.as.primary.operand;
                std.debug.print("PrimaryExpression {[operand]s}\n", .{ .operand = operand.lexeme(source) });
            },
        }
    }
};
