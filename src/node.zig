const std = @import("std");
const Allocator = std.mem.Allocator;

const Token = @import("token.zig").Token;

const ProgramNode = struct {
    statements: std.ArrayList(*Node),
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

    pub fn initProgramNode(allocator: *Allocator) !*Node {
        var node = try allocator.create(Node);
        node.tag = Node.Tag.Program;
        node.as = Union{ .program = ProgramNode{ .statements = std.ArrayList(*Node).init(allocator.*) } };
        return node;
    }

    pub fn initBinaryNode(allocator: *Allocator, left: *Node, operator: Token, right: *Node) !*Node {
        var node = try allocator.create(Node);
        node.tag = Node.Tag.Binary;
        node.as = Union{ .binary = BinaryNode{ .operator = operator, .left = left, .right = right } };
        return node;
    }

    pub fn initUnaryNode(allocator: *Allocator, operator: Token, operand: *Node) !*Node {
        var node = try allocator.create(Node);
        node.tag = Node.Tag.Unary;
        node.as = Union{ .unary = UnaryNode{ .operator = operator, .operand = operand } };
        return node;
    }

    pub fn initPrimaryNode(allocator: *Allocator, operand: Token) !*Node {
        var node = try allocator.create(Node);
        node.tag = Node.Tag.Primary;
        node.as = Union{ .primary = PrimaryNode{ .operand = operand } };
        return node;
    }

    pub fn free(self: *Node, allocator: *Allocator) void {
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

    pub fn debug(self: *Node, source: []const u8, indent: u32) void {
        const width = 4;
        switch (self.tag) {
            .Program => {
                std.debug.print("{[empty]s: >[indent]}Program\n", .{ .empty = "", .indent = indent });
                for (self.as.program.statements.items) |statement| {
                    statement.debug(source, indent + width);
                }
            },
            .Binary => {
                std.debug.print("{[empty]s: >[indent]}BinaryExpression {[operator]s}\n", .{ .empty = "", .indent = indent, .operator = self.as.binary.operator.lexeme(source) });
                self.as.binary.left.debug(source, indent + width);
                self.as.binary.right.debug(source, indent + width);
            },
            .Unary => {
                std.debug.print("{[empty]s: >[indent]}UnaryExpression {[operator]s}\n", .{ .empty = "", .indent = indent, .operator = self.as.unary.operator.lexeme(source) });
                self.as.unary.operand.debug(source, indent + width);
            },
            .Primary => {
                const operand = self.as.primary.operand;
                std.debug.print("{[empty]s: >[indent]}{[kind]s} {[operand]s}\n", .{ .empty = "", .kind = operand.tag.toString(), .indent = indent, .operand = operand.lexeme(source) });
            },
        }
    }
};
