const std = @import("std");
const Allocator = std.mem.Allocator;

const Ansi = @import("ansi.zig");
const Node = @import("node.zig").Node;
const Array = @import("array.zig").Array;
const Value = @import("value.zig").Value;
const Object = @import("object.zig").Object;

pub const OpCode = enum(u8) {
    PUSH,
    POP,
    ADD,
    SUB,
    MUL,
    POW,
    DIV,
    MOD,
    NEG,
    CAT,
    EQ,
    NEQ,
    LT,
    GT,
    LTEQ,
    GTEQ,
    LOR,
    LAND,
    LNOT,
    HALT,
    SETG,
    GETG,

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
        for (self.constants.items) |*constant| constant.deinit();
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
        if (self.constants.searchLinearIndex(value.*, Value.compare)) |found| {
            value.deinit();
            index = found;
        } else {
            try self.constants.push(value.*);
            index = self.constants.count() - 1;
        }
        if (index > std.math.maxInt(u24)) return Error.ConstantPoolOverflow;
        try self.pushOpCode(OpCode.PUSH);
        try self.pushByte(@intCast(index >> 16));
        try self.pushByte(@intCast(index >> 8));
        try self.pushByte(@intCast(index));
    }

    fn pushInstruction(self: *Chunk, opcode: OpCode, value: *Value) !void {
        var index: usize = undefined;
        if (self.constants.searchLinearIndex(value.*, Value.compare)) |found| {
            value.deinit();
            index = found;
        } else {
            try self.constants.push(value.*);
            index = self.constants.count() - 1;
        }
        if (index > std.math.maxInt(u24)) return Error.ConstantPoolOverflow;
        try self.pushOpCode(opcode);
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
            .PUSH, .SETG, .GETG => {
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
            .PUSH, .SETG, .GETG => {
                const value = self.getConstant(instruction.index);
                std.debug.print(Ansi.Cyan ++ "{x:0>8}" ++ Ansi.Reset ++ ": " ++ Ansi.Dim ++ "{x:0>2} {x:0>6}    " ++ Ansi.Reset ++ Ansi.Bold ++ "{}" ++ Ansi.Reset ++ "    ({s} " ++ Ansi.Cyan ++ "{}" ++ Ansi.Reset ++ ")\n" ++ Ansi.Reset, .{
                    address,
                    @as(u8, @intFromEnum(instruction.opcode)),
                    instruction.index,
                    instruction.opcode,
                    value.tagName(),
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
        while (i < bytes) i = self.debugInstruction(i);
    }

    pub fn compile(self: *Chunk, root: *Node, source: []const u8) !void {
        switch (root.tag) {
            .Program => {
                const node = root.as.program;
                const last = node.statements.peek() orelse return;
                for (node.statements.items) |statement| {
                    try self.compile(statement, source);
                    if (statement != last) try self.pushOpCode(.POP);
                }
                try self.pushOpCode(.HALT);
            },
            .Block => {
                const node = root.as.block;
                const last = node.statements.peek() orelse {
                    var value = Value.initNull();
                    try self.pushConstant(&value);
                    return;
                };
                for (node.statements.items) |statement| {
                    try self.compile(statement, source);
                    if (statement != last) try self.pushOpCode(.POP);
                }
            },
            .Binary => {
                const node = root.as.binary;
                if (node.operator.tag == .Equal) {
                    try self.compile(node.right, source);
                    var identifier = try Value.initObjectStringLiteral(self.allocator, node.left.as.primary.operand.lexeme);
                    try self.pushInstruction(.SETG, &identifier);
                    return;
                }
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
                    .EqualEqual => try self.pushOpCode(.EQ),
                    .BangEqual => try self.pushOpCode(.NEQ),
                    .Less => try self.pushOpCode(.LT),
                    .LessEqual => try self.pushOpCode(.LTEQ),
                    .Greater => try self.pushOpCode(.GT),
                    .GreaterEqual => try self.pushOpCode(.GTEQ),
                    .PipePipe => try self.pushOpCode(.LOR),
                    .AndAnd => try self.pushOpCode(.LAND),
                    else => std.debug.panic("{s} not defined for binary node", .{node.operator.tag}),
                }
            },
            .Unary => {
                const node = root.as.unary;
                try self.compile(node.operand, source);
                switch (node.operator.tag) {
                    .Bang => try self.pushOpCode(.LNOT),
                    .Minus => try self.pushOpCode(.NEG),
                    .Plus => return,
                    else => std.debug.panic("{} not defined for unary node", .{node.operator.tag}),
                }
            },
            .Primary => {
                const node = root.as.primary;
                var value: Value = undefined;
                switch (node.operand.tag) {
                    .KeywordNull => {
                        value = Value.initNull();
                    },
                    .KeywordTrue => {
                        value = Value.initBoolean(true);
                    },
                    .KeywordFalse => {
                        value = Value.initBoolean(false);
                    },
                    .Number => {
                        const number = try std.fmt.parseFloat(f64, node.operand.lexeme);
                        value = Value.initNumber(number);
                    },
                    .String => {
                        const string = node.operand.stringLiteral();
                        value = try Value.initObjectStringLiteral(self.allocator, string);
                    },
                    .Identifier => {
                        var identifier = try Value.initObjectStringLiteral(self.allocator, node.operand.lexeme);
                        try self.pushInstruction(.GETG, &identifier);
                        return;
                    },
                    else => {
                        std.debug.panic("{} not defined for primary node", .{node.operand.tag});
                    },
                }
                try self.pushConstant(&value);
            },
        }
    }
};
