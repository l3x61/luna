const std = @import("std");
const Allocator = std.mem.Allocator;

const Node = @import("node.zig").Node;
const Value = @import("value.zig").Value;

pub const Luna = struct {
    pub fn evaluate(root: *Node, source: []const u8) !Value {
        switch (root.tag) {
            .Program => {
                const node = root.as.program;
                var value = Value.init();
                for (node.statements.items) |statement| {
                    value = try Luna.evaluate(statement, source);
                }
                return value;
            },
            .Binary => {
                const node = root.as.binary;
                const left = try Luna.evaluate(node.left, source);
                const right = try Luna.evaluate(node.right, source);
                switch (node.operator.tag) {
                    .Plus => return Value.add(left, right),
                    .Minus => return Value.subtract(left, right),
                    .Star => return Value.multiply(left, right),
                    .StarStar => return Value.power(left, right),
                    .Slash => return try Value.divide(left, right),
                    .Percent => return try Value.modulo(left, right),
                    else => std.debug.panic("{s} not defined for binary node", .{node.operator.tag.toString()}),
                }
            },
            .Unary => {
                const node = root.as.unary;
                const value = try Luna.evaluate(node.operand, source);
                switch (node.operator.tag) {
                    .Plus => return value,
                    .Minus => return Value.negate(value),
                    else => std.debug.panic("{s} not defined for unary node", .{node.operator.tag.toString()}),
                }
            },
            .Primary => {
                const node = root.as.primary;
                switch (node.operand.tag) {
                    .Number => return Value.initNumber(try std.fmt.parseFloat(f64, node.operand.lexeme(source))),
                    else => std.debug.panic("{s} not defined for primary node", .{node.operand.tag.toString()}),
                }
            },
        }
    }
};
