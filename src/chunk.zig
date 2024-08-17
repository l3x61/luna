const std = @import("std");
const Allocator = std.mem.Allocator;

const Ansi = @import("ansi.zig");
const Node = @import("node.zig").Node;
const Array = @import("array.zig").Array;
const Value = @import("value.zig").Value;
const Object = @import("object.zig").Object;

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
    CAT,
    HALT,

    pub fn format(self: OpCode, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("{s}", .{@tagName(self)});
    }
};

pub const Instruction = struct {
    opcode: OpCode,
    index: u24,
    next: usize,
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
        for (self.constants.items) |*constant| {
            constant.deinit();
        }
        self.constants.deinit();
    }

    fn pushByte(self: *Chunk, byte: u8) !void {
        try self.bytecode.push(byte);
    }

    fn pushOpCode(self: *Chunk, opCode: OpCode) !void {
        try self.pushByte(@intFromEnum(opCode));
    }

    fn pushConstant(self: *Chunk, value: *Value) !void {
        var index: usize = undefined;
        if (self.constants.searchLinear(value.*, Value.compare)) |found| {
            value.deinit();
            index = found;
        } else {
            try self.constants.push(value.*);
            index = self.constants.count() - 1;
        }
        if (index > std.math.maxInt(u24)) {
            return Error.ConstantPoolOverflow;
        }
        try self.pushOpCode(OpCode.CONST);
        try self.pushByte(@intCast(index >> 16));
        try self.pushByte(@intCast(index >> 8));
        try self.pushByte(@intCast(index));
    }

    pub fn getInstruction(self: *Chunk, index: usize) Instruction {
        if (index >= self.bytecode.count()) {
            return Instruction{
                .opcode = .HALT,
                .index = 0,
                .next = index,
            };
        }
        const opcode = @as(OpCode, @enumFromInt(self.bytecode.get(index).?));
        switch (opcode) {
            .CONST => {
                const high: u24 = @as(u24, self.bytecode.get(index + 1).?) << 16;
                const mid: u24 = @as(u24, self.bytecode.get(index + 2).?) << 8;
                const low: u24 = self.bytecode.get(index + 3).?;
                return Instruction{
                    .opcode = opcode,
                    .index = high | mid | low,
                    .next = index + 4,
                };
            },
            else => return Instruction{
                .opcode = opcode,
                .index = 0,
                .next = index + 1,
            },
        }
    }

    pub fn getConstant(self: *Chunk, index: usize) Value {
        return self.constants.get(index).?;
    }

    pub fn debugInstruction(self: *Chunk, address: usize) usize {
        const instruction = self.getInstruction(address);
        switch (instruction.opcode) {
            .CONST => {
                const value = self.getConstant(instruction.index);
                std.debug.print(Ansi.Cyan ++ "{x:0>8}" ++ Ansi.Reset ++ ": " ++ Ansi.Dim ++ "{x:0>2} {x:0>6}    " ++ Ansi.Reset ++ Ansi.Bold ++ "{}" ++ Ansi.Reset ++ " {d}    ({} " ++ Ansi.Cyan ++ "{}" ++ Ansi.Reset ++ ")\n" ++ Ansi.Reset, .{
                    address,
                    @as(u8, @intFromEnum(instruction.opcode)),
                    instruction.index,
                    instruction.opcode,
                    instruction.index,
                    value.tag,
                    value,
                });
            },
            else => {
                std.debug.print(Ansi.Cyan ++ "{x:0>8}" ++ Ansi.Reset ++ ": " ++ Ansi.Dim ++ "{x:0>2}           " ++ Ansi.Reset ++ Ansi.Bold ++ "{}\n" ++ Ansi.Reset, .{ address, self.bytecode.get(address).?, instruction.opcode });
            },
        }
        return instruction.next;
    }

    pub fn debug(self: *Chunk) void {
        const bytes = self.bytecode.count();
        var i: usize = 0;
        while (i < bytes) {
            i = self.debugInstruction(i);
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
                try self.pushOpCode(.HALT);
            },
            .Block => {
                const node = root.as.block;
                const last = node.statements.last() orelse {
                    var value = Value.init();
                    try self.pushConstant(&value);
                    return;
                };
                for (node.statements.items) |statement| {
                    try self.compile(statement, source);
                    if (statement != last) {
                        try self.pushOpCode(.POP);
                    }
                }
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
                    .DotDot => try self.pushOpCode(.CAT),
                    else => std.debug.panic("{s} not defined for binary node", .{node.operator.tag}),
                }
            },
            .Unary => {
                const node = root.as.unary;
                try self.compile(node.operand, source);
                switch (node.operator.tag) {
                    .Plus => return,
                    .Minus => try self.pushOpCode(.NEG),
                    else => std.debug.panic("{} not defined for unary node", .{node.operator.tag}),
                }
            },
            .Primary => {
                const node = root.as.primary;
                var value: Value = undefined;
                switch (node.operand.tag) {
                    .Number => value = Value.initNumber(try std.fmt.parseFloat(f64, node.operand.lexeme(source))),
                    .String => value = try Value.initObject(try Object.initString(self.allocator, node.operand.stringValue(source))),
                    else => std.debug.panic("{} not defined for primary node", .{node.operand.tag}),
                }
                try self.pushConstant(&value);
            },
        }
    }
};
