const std = @import("std");
const Allocator = std.mem.Allocator;

const Ansi = @import("ansi.zig");
const Node = @import("node.zig").Node;
const Array = @import("array.zig").Array;
const Value = @import("value.zig").Value;

pub const OpCode = enum(u8) {
    CONST,
    POP,
    ADD,
    SUB,
    MUL,
    POW,
    DIV,
    MOD,
    NEG,
    RETURN,

    pub fn toString(self: OpCode) []const u8 {
        return @tagName(self);
    }
};

pub const Chunk = struct {
    bytecode: Array(u8),
    constants: Array(Value),
    allocator: Allocator,

    pub const Error = error{
        ConstantPoolOverflow,
    };

    pub fn init(allocator: Allocator) Chunk {
        return Chunk{
            .bytecode = Array(u8).init(allocator),
            .constants = Array(Value).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Chunk) void {
        self.bytecode.deinit();
        self.constants.deinit();
    }

    pub fn pushByte(self: *Chunk, byte: u8) !void {
        try self.bytecode.push(byte);
    }

    pub fn pushOpCode(self: *Chunk, opCode: OpCode) !void {
        try self.pushByte(@intFromEnum(opCode));
    }

    pub fn pushConstant(self: *Chunk, value: Value) !void {
        var index: usize = undefined;
        if (self.constants.find(value, Value.equalStrict)) |found| {
            index = found;
        } else {
            try self.constants.push(value);
            index = self.constants.items.len - 1;
        }
        if (index > std.math.maxInt(u24)) {
            return Error.ConstantPoolOverflow;
        }
        try self.pushOpCode(OpCode.CONST);
        try self.pushByte(@intCast(index >> 16));
        try self.pushByte(@intCast(index >> 8));
        try self.pushByte(@intCast(index));
    }

    pub fn debug(self: *Chunk) void {
        const bytes = self.bytecode.items.len;
        var i: usize = 0;
        while (i < bytes) : (i += 1) {
            const byte = self.bytecode.items[i];
            switch (@as(OpCode, @enumFromInt(byte))) {
                .CONST => {
                    const high: usize = self.bytecode.items[i + 1];
                    const mid: usize = self.bytecode.items[i + 2];
                    const low: usize = self.bytecode.items[i + 3];
                    const index: usize = high << 16 | mid << 8 | low;
                    //const value = self.constants.items[index];
                    std.debug.print("{x:0>8}: " ++ Ansi.Dim ++ "{x:0>2} {x:0>2} {x:0>2} {x:0>2} " ++ Ansi.Reset ++ " {s} {d}\n", .{
                        i,
                        byte,
                        high,
                        mid,
                        low,
                        @as(OpCode, @enumFromInt(byte)).toString(),
                        index,
                    });
                    i += 3;
                },
                else => {
                    std.debug.print("{x:0>8}: " ++ Ansi.Dim ++ "{x:0>2}          " ++ Ansi.Reset ++ " {s}\n", .{
                        i,
                        byte,
                        @as(OpCode, @enumFromInt(byte)).toString(),
                    });
                },
            }
        }
    }

    pub fn compile(self: *Chunk, root: *Node, source: []const u8) !void {
        switch (root.tag) {
            .Program => {
                const node = root.as.program;
                const last = node.statements.last() orelse return;
                for (node.statements.items) |statement| {
                    try self.compile(statement, source);
                    if (statement != last) {
                        try self.pushOpCode(.POP);
                    }
                }
                try self.pushOpCode(.RETURN);
            },
            .Binary => {
                const node = root.as.binary;
                try self.compile(node.left, source);
                try self.compile(node.right, source);
                switch (node.operator.tag) {
                    .Plus => try self.pushOpCode(.ADD),
                    .Minus => try self.pushOpCode(.SUB),
                    .Star => try self.pushOpCode(.MUL),
                    .StarStar => try self.pushOpCode(.POW),
                    .Slash => try self.pushOpCode(.DIV),
                    .Percent => try self.pushOpCode(.MOD),
                    else => std.debug.panic("{s} not defined for binary node", .{node.operator.tag.toString()}),
                }
            },
            .Unary => {
                const node = root.as.unary;
                try self.compile(node.operand, source);
                switch (node.operator.tag) {
                    .Plus => return, // NO OP ?
                    .Minus => try self.pushOpCode(.NEG),
                    else => std.debug.panic("{s} not defined for unary node", .{node.operator.tag.toString()}),
                }
            },
            .Primary => {
                const node = root.as.primary;
                var value: Value = undefined;
                switch (node.operand.tag) {
                    .Number => value = Value.initNumber(try std.fmt.parseFloat(f64, node.operand.lexeme(source))),
                    else => std.debug.panic("{s} not defined for primary node", .{node.operand.tag.toString()}),
                }
                try self.pushConstant(value);
            },
        }
    }
};
