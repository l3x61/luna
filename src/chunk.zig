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
    POPN,
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
    SETL,
    GETL,

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
        InvalidAssignmentTarget,
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

    fn addConstant(self: *Chunk, value: *Value) !void {
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
        try self.addConstant(value);
    }

    fn emitOpCodeIndex(self: *Chunk, opcode: OpCode, index: usize) !void {
        try self.emitOpCode(opcode);
        try self.emitByte(@intCast(index >> 16));
        try self.emitByte(@intCast(index >> 8));
        try self.emitByte(@intCast(index));
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
            .PUSH, .SETG, .GETG, .SETL, .GETL, .POPN => {
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
                std.debug.print("{x:0>8}: " ++ Ansi.Dim ++ "{x:0>2} {x:0>6}    " ++ Ansi.Reset ++ Ansi.Bold ++ "{}" ++ Ansi.Reset ++ "    ({s} " ++ Ansi.Cyan ++ "{}" ++ Ansi.Reset ++ ")\n" ++ Ansi.Reset, .{
                    address,
                    @as(u8, @intFromEnum(instruction.opcode)),
                    instruction.index,
                    instruction.opcode,
                    value.tagName(),
                    value,
                });
            },
            .SETL, .GETL, .POPN => {
                std.debug.print("{x:0>8}: " ++ Ansi.Dim ++ "{x:0>2} {x:0>6}    " ++ Ansi.Reset ++ Ansi.Bold ++ "{} {d}\n" ++ Ansi.Reset, .{
                    address,
                    @as(u8, @intFromEnum(instruction.opcode)),
                    instruction.index,
                    instruction.opcode,
                    instruction.index,
                });
            },
            else => {
                std.debug.print("{x:0>8}: " ++ Ansi.Dim ++ "{x:0>2}           " ++ Ansi.Reset ++ Ansi.Bold ++ "{}\n" ++ Ansi.Reset, .{ address, self.bytecode.get(address).?, instruction.opcode });
            },
        }
        return instruction.next;
    }

    pub fn debug(self: *Chunk) void {
        const bytes = self.bytecode.count();
        var i: usize = 0;
        while (i < bytes) i = self.debugInstruction(i);
    }

    const Local = struct {
        token: Token,
        level: usize,

        const Uninizialized = std.math.maxInt(usize); // locals are limited to std.math.maxInt(u24)

        pub fn init(token: Token, level: usize) Local {
            return Local{ .token = token, .level = level };
        }

        /// WARNING: does not compare the level
        pub fn compare(a: Local, b: Local) bool {
            return std.mem.eql(u8, a.token.lexeme, b.token.lexeme);
        }
    };

    const Context = struct {
        locals: Array(Local),
        level: usize,

        const Error = error{
            TooManyLocals,
            LocalAlreadyDeclared,
            LocalNotInitialized,
            LocalNotDeclared,
        };

        pub fn init(allocator: Allocator) Context {
            return Context{
                .locals = Array(Local).init(allocator),
                .level = 0,
            };
        }

        pub fn deinit(self: *Context) void {
            self.locals.deinit();
        }

        pub fn enterScope(self: *Context) void {
            self.level += 1;
        }

        pub fn leaveScope(self: *Context) usize {
            var locals_in_scope: usize = 0;
            while (self.locals.peek()) |local| {
                if (local.level == self.level) _ = self.locals.pop() else break;
                locals_in_scope += 1;
            }
            self.level -= 1;
            return locals_in_scope;
        }

        pub fn isGlobalScope(self: *Context) bool {
            return self.level == 0;
        }

        pub fn declareLocal(self: *Context, token: Token) !usize {
            if (self.locals.count() == std.math.maxInt(u24)) return Context.Error.TooManyLocals;
            try self.locals.push(Local.init(token, Local.Uninizialized));
            return self.locals.count() - 1;
        }

        pub fn resolveLocal(self: *Context, token: Token) !usize {
            const index = self.locals.searchLinearReverseIndex(Local{ .token = token, .level = Local.Uninizialized }, Local.compare);
            if (index) |i| {
                if (self.locals.get(i).?.level == Local.Uninizialized) return Context.Error.LocalNotDeclared;
                return i;
            }
            return Context.Error.LocalNotDeclared;
        }

        pub fn markInitialized(self: *Context) void {
            self.locals.items[self.locals.count() - 1].level = self.level;
        }
    };

    pub fn compile(self: *Chunk, root: *Node) !void {
        var context = Context.init(self.allocator);
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
                        try self.emitOpCodeConstant(.PUSH, &value);
                    }
                    var identifier = try Value.initObjectStringLiteral(self.allocator, node.name.lexeme);
                    try self.emitOpCodeConstant(.SETG, &identifier);
                } else {
                    const index = try context.declareLocal(node.name);
                    if (node.value) |value| {
                        try self.compileInternal(value, context);
                    } else {
                        var value = Value.initNull();
                        try self.emitOpCodeConstant(.PUSH, &value);
                    }
                    try self.emitOpCodeIndex(.SETL, index);
                    context.markInitialized();
                }
            },
            .Block => {
                const node = root.as.block;
                context.enterScope();
                for (node.statements.items) |statement| {
                    try self.compileInternal(statement, context);
                    if (statement.tag != .VariableDeclaration and statement.tag != .Block) try self.emitOpCode(.POP);
                }
                try self.emitOpCodeIndex(.POPN, context.leaveScope());
            },
            .Binary => {
                const node = root.as.binary;
                if (node.operator.tag == .Equal) {
                    if (node.left.tag != .Primary and node.left.as.primary.operand.tag == .Identifier) return Error.InvalidAssignmentTarget;
                    try self.compileInternal(node.right, context);
                    if (context.isGlobalScope()) {
                        var identifier = try Value.initObjectStringLiteral(self.allocator, node.left.as.primary.operand.lexeme);
                        try self.emitOpCodeConstant(.SETG, &identifier);
                    } else {
                        const index = context.resolveLocal(node.left.as.primary.operand) catch {
                            var identifier = try Value.initObjectStringLiteral(self.allocator, node.left.as.primary.operand.lexeme);
                            try self.emitOpCodeConstant(.SETG, &identifier);
                            return;
                        };
                        try self.emitOpCodeIndex(.SETL, index);
                    }
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
                    .Identifier => {
                        var identifier = try Value.initObjectStringLiteral(self.allocator, node.operand.lexeme);
                        if (context.isGlobalScope()) {
                            try self.emitOpCodeConstant(.GETG, &identifier);
                            return;
                        } else {
                            const index = context.resolveLocal(node.operand) catch {
                                try self.emitOpCodeConstant(.GETG, &identifier);
                                return;
                            };
                            try self.emitOpCodeIndex(.GETL, index);
                            identifier.deinit();
                            return;
                        }
                    },
                    else => unreachable,
                };
                try self.emitOpCodeConstant(.PUSH, &value);
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
            else => std.debug.panic("{s}: {s}\n", .{ @src().fn_name, tag }),
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
