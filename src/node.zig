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
                for (self.as.program.statements.items) |statement| statement.free(allocator);
                self.as.program.statements.deinit();
                allocator.destroy(self);
            },
            .Block => {
                for (self.as.block.statements.items) |statement| statement.free(allocator);
                self.as.block.statements.deinit();
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

    fn debugInternal(self: *Node, prefix: *String, source: []const u8, is_last: bool) !void {
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
                    try statement.debugInternal(&_prefix, source, is_last_statement);
                }
            },
            .Block => {
                std.debug.print("Block\n", .{});
                for (self.as.block.statements.items, 0..) |statement, index| {
                    const is_last_statement = index == self.as.block.statements.count() - 1;
                    try statement.debugInternal(&_prefix, source, is_last_statement);
                }
            },
            .Binary => {
                std.debug.print("Binary " ++ Ansi.Magenta ++ "{s}\n" ++ Ansi.Reset, .{self.as.binary.operator.lexeme});
                try self.as.binary.left.debugInternal(&_prefix, source, false);
                try self.as.binary.right.debugInternal(&_prefix, source, true);
            },
            .Unary => {
                std.debug.print("Unary " ++ Ansi.Magenta ++ "{s}\n" ++ Ansi.Reset, .{self.as.unary.operator.lexeme});
                try self.as.unary.operand.debugInternal(&_prefix, source, true);
            },
            .Primary => {
                const operand = self.as.primary.operand;
                std.debug.print("{} " ++ Ansi.Cyan ++ "{s}\n" ++ Ansi.Reset, .{ operand.tag, operand.lexeme });
            },
        }
    }
};
