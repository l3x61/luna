const std = @import("std");
const Allocator = std.mem.Allocator;

const Ansi = @import("ansi.zig");
const Token = @import("token.zig").Token;
const Node = @import("node.zig").Node;
const Array = @import("array.zig").Array;
const Value = @import("value.zig").Value;
const Object = @import("object.zig").Object;

pub const OpCode = enum(u8) {
    NOP,
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
    allocator: Allocator,
    bytecode: Array(u8),
    constants: Array(Value),

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

    fn emitByte(self: *Chunk, byte: u8) !void {
        try self.bytecode.push(byte);
    }

    fn emitOpCode(self: *Chunk, opCode: OpCode) !void {
        try self.emitByte(@intFromEnum(opCode));
    }

    fn emitConstant(self: *Chunk, value: *Value) !void {
        var index: usize = undefined;
        if (self.constants.searchLinearIndex(value.*, Value.compare)) |found| {
            value.deinit();
            index = found;
        } else {
            try self.constants.push(value.*);
            index = self.constants.count() - 1;
        }
        if (index > std.math.maxInt(u24)) return Error.ConstantPoolOverflow;
        try self.emitByte(@intCast(index >> 16));
        try self.emitByte(@intCast(index >> 8));
        try self.emitByte(@intCast(index));
    }

    fn emitOpCodeConstant(self: *Chunk, opcode: OpCode, value: *Value) !void {
        try self.emitOpCode(opcode);
        try self.emitConstant(value);
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
        return self.constants.get(index) orelse unreachable;
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

    const Context = struct {
        level: usize,

        pub fn init() Context {
            return Context{
                .level = 0,
            };
        }

        pub fn deinit(self: *Context) void {
            _ = self;
        }

        pub fn enterScope(self: *Context) void {
            self.level += 1;
        }

        pub fn leaveScope(self: *Context) void {
            self.level -= 1;
        }

        pub fn isGlobalScope(self: *Context) bool {
            return self.level == 0;
        }
    };

    pub fn compile(self: *Chunk, root: *Node) !void {
        var context = Context.init();
        defer context.deinit();
        return self.compileInternal(root, &context);
    }

    pub fn compileInternal(self: *Chunk, root: *Node, context: *Context) !void {
        switch (root.tag) {
            .Program => {
                const node = root.as.program;
                const last = node.statements.peek() orelse return;
                for (node.statements.items) |statement| {
                    try self.compileInternal(statement, context);
                    if (statement != last) try self.emitOpCode(.POP);
                }
                try self.emitOpCode(.HALT);
            },
            .VariableDeclaration => {
                const node = root.as.variable_declaration;
                if (context.isGlobalScope()) {
                    if (node.value) |value| {
                        try self.compileInternal(value, context);
                    } else {
                        var value = Value.initNull();
                        try self.emitConstant(&value);
                    }
                    var identifier = try Value.initObjectStringLiteral(self.allocator, node.name.lexeme);
                    try self.emitOpCodeConstant(.SETG, &identifier);
                }
            },
            .Block => {
                const node = root.as.block;
                const last = node.statements.peek() orelse return;
                context.enterScope();
                for (node.statements.items) |statement| {
                    try self.compileInternal(statement, context);
                    if (statement != last) try self.emitOpCode(.POP); // TODO: only emit on expression statements
                }
                context.leaveScope();
            },
            .Binary => {
                const node = root.as.binary;
                if (node.operator.tag == .Equal) {
                    try self.compileInternal(node.right, context);
                    var identifier = try Value.initObjectStringLiteral(self.allocator, node.left.as.primary.operand.lexeme);
                    try self.emitOpCodeConstant(.SETG, &identifier);
                    return;
                }
                try self.compileInternal(node.left, context);
                try self.compileInternal(node.right, context);
                try self.emitOpCode(getBinaryOpCode(node.operator.tag));
            },
            .Unary => {
                const node = root.as.unary;
                try self.compileInternal(node.operand, context);
                try self.emitOpCode(getUnaryOpCode(node.operator.tag));
            },
            .Primary => {
                const node = root.as.primary;
                var value = try switch (node.operand.tag) {
                    .KeywordNull => Value.initNull(),
                    .KeywordTrue => Value.initBoolean(true),
                    .KeywordFalse => Value.initBoolean(false),
                    .Number => Value.initNumber(try std.fmt.parseFloat(f64, node.operand.lexeme)),
                    .String => Value.initObjectStringLiteral(self.allocator, node.operand.stringLiteral()),
                    .Identifier => Value.initObjectStringLiteral(self.allocator, node.operand.lexeme),
                    else => unreachable,
                };
                try self.emitOpCodeConstant(
                    if (node.operand.tag == .Identifier) .GETG else .PUSH,
                    &value,
                );
            },
        }
    }

    fn getBinaryOpCode(tag: Token.Tag) OpCode {
        return switch (tag) {
            .Plus => .ADD,
            .Minus => .SUB,
            .Star => .MUL,
            .StarStar => .POW,
            .Slash => .DIV,
            .Percent => .MOD,
            .DotDot => .CAT,
            .EqualEqual => .EQ,
            .BangEqual => .NEQ,
            .Less => .LT,
            .LessEqual => .LTEQ,
            .Greater => .GT,
            .GreaterEqual => .GTEQ,
            .PipePipe => .LOR,
            .AndAnd => .LAND,
            else => unreachable,
        };
    }

    fn getUnaryOpCode(tag: Token.Tag) OpCode {
        return switch (tag) {
            .Bang => .LNOT,
            .Minus => .NEG,
            .Plus => .NOP,
            else => unreachable,
        };
    }
};
