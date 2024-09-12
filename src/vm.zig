const std = @import("std");
const Allocator = std.mem.Allocator;

const Ansi = @import("ansi.zig");
const Node = @import("node.zig").Node;
const Array = @import("array.zig").Array;
const Chunk = @import("chunk.zig").Chunk;
const OpCode = @import("chunk.zig").OpCode;
const Instruction = @import("chunk.zig").Instruction;
const Value = @import("value.zig").Value;
const Object = @import("object.zig").Object;
const String = @import("string.zig").String;
const Table = @import("table.zig").Table;

pub const Vm = struct {
    allocator: Allocator,
    stack: Array(Value),
    chunk: Chunk,
    ip: usize,
    root: ?*Object = null,
    globals: *Table,
    lastPopped: ?*Value = null,

    pub const Errror = error{
        StackUnderflow,
    };

    pub fn init(allocator: Allocator, chunk: Chunk, globals: *Table) !Vm {
        return Vm{
            .allocator = allocator,
            .stack = try Array(Value).initCapacity(allocator, 1024),
            .chunk = chunk,
            .ip = 0,
            .globals = globals,
        };
    }

    pub fn deinit(self: *Vm) void {
        while (self.root) |node| {
            const next = node.next;
            node.deinit();
            self.root = next;
        }
        self.stack.deinit();
    }

    fn trackValue(self: *Vm, value: Value) void {
        if (value.tag == .Object) {
            value.as.object.next = self.root;
            self.root = value.as.object;
        }
    }

    fn stackPush(self: *Vm, value: Value) !void {
        try self.stack.push(value);
    }

    fn stackPeek(self: *Vm) !Value {
        return self.stack.peek() orelse Errror.StackUnderflow;
    }

    fn stackPop(self: *Vm) !Value {
        return self.stack.pop() orelse Errror.StackUnderflow;
    }

    pub fn run(self: *Vm, debug: bool) !void {
        while (true) {
            if (debug) std.debug.print("\n", .{});
            if (debug) _ = self.chunk.debugInstruction(self.ip);
            const instruction = self.chunk.getInstruction(self.ip);
            self.ip = instruction.next;
            switch (instruction.opcode) {
                .NOP => {},
                .PUSH => try self.stackPush(self.chunk.getConstant(instruction.index)),
                .POP => {
                    self.lastPopped = &self.stack.items[self.stack.items.len - 1];
                    try self.stack.popN(1);
                },
                .POPN => try self.stack.popN(instruction.index),
                .ADD => {
                    const right = try (try self.stackPop()).toNumber();
                    const left = try (try self.stackPop()).toNumber();
                    try self.stackPush(Value.initNumber(left + right));
                },
                .SUB => {
                    const right = try (try self.stackPop()).toNumber();
                    const left = try (try self.stackPop()).toNumber();
                    try self.stackPush(Value.initNumber(left - right));
                },
                .MUL => {
                    const right = try (try self.stackPop()).toNumber();
                    const left = try (try self.stackPop()).toNumber();
                    try self.stackPush(Value.initNumber(left * right));
                },
                .POW => {
                    const right = try (try self.stackPop()).toNumber();
                    const left = try (try self.stackPop()).toNumber();
                    try self.stackPush(Value.initNumber(std.math.pow(f64, left, right)));
                },
                .DIV => {
                    const right = try (try self.stackPop()).toNumber();
                    const left = try (try self.stackPop()).toNumber();
                    try self.stackPush(Value.initNumber(left / right));
                },
                .MOD => {
                    const right = try (try self.stackPop()).toNumber();
                    const left = try (try self.stackPop()).toNumber();
                    try self.stackPush(Value.initNumber(@mod(left, right)));
                },
                .NEG => {
                    const value = try (try self.stackPop()).toNumber();
                    try self.stackPush(Value.initNumber(-value));
                },
                .CAT => {
                    var right = try (try self.stackPop()).toString(self.allocator);
                    defer right.deinit();

                    var left = try (try self.stackPop()).toString(self.allocator);
                    try left.appendString(right);

                    const value = try Value.initObjectString(self.allocator, left);
                    self.trackValue(value);
                    try self.stackPush(value);
                },
                .EQ => {
                    const right = try (try self.stackPop()).clone();
                    const left = try (try self.stackPop()).clone();
                    try self.stackPush(Value.initBoolean(Value.compare(left, right)));
                },
                .NEQ => {
                    const right = try (try self.stackPop()).clone();
                    const left = try (try self.stackPop()).clone();
                    try self.stackPush(Value.initBoolean(!Value.compare(left, right)));
                },
                .LT => {
                    const right = try (try self.stackPop()).toNumber();
                    const left = try (try self.stackPop()).toNumber();
                    try self.stackPush(Value.initBoolean(left < right));
                },
                .LTEQ => {
                    const right = try (try self.stackPop()).toNumber();
                    const left = try (try self.stackPop()).toNumber();
                    try self.stackPush(Value.initBoolean(left <= right));
                },
                .GT => {
                    const right = try (try self.stackPop()).toNumber();
                    const left = try (try self.stackPop()).toNumber();
                    try self.stackPush(Value.initBoolean(left > right));
                },
                .GTEQ => {
                    const right = try (try self.stackPop()).toNumber();
                    const left = try (try self.stackPop()).toNumber();
                    try self.stackPush(Value.initBoolean(left >= right));
                },
                .LNOT => {
                    const operand = (try self.stackPop()).toBoolean();
                    try self.stackPush(Value.initBoolean(!operand));
                },
                .LOR => {
                    const right = (try self.stackPop()).toBoolean();
                    const left = (try self.stackPop()).toBoolean();
                    try self.stackPush(Value.initBoolean(left or right));
                },
                .LAND => {
                    const right = (try self.stackPop()).toBoolean();
                    const left = (try self.stackPop()).toBoolean();
                    try self.stackPush(Value.initBoolean(left and right));
                },
                .SETG => {
                    var key = try (self.chunk.getConstant(instruction.index)).clone();
                    const value = try (try self.stackPeek()).clone();
                    if (try self.globals.set(key, value) == false) key.deinit();
                },
                .GETG => {
                    const key = self.chunk.getConstant(instruction.index);
                    const value = self.globals.get(key);
                    try self.stackPush(if (value) |val| val else Value.initNull());
                },
                .SETL => {
                    const value = self.stack.peek().?;
                    try self.stack.set(instruction.index, value);
                },
                .GETL => {
                    const value = self.stack.get(instruction.index).?;
                    try self.stackPush(value);
                },
                .HALT => break,
            }
            if (debug) self.debugStack();
        }
        if (self.lastPopped) |value| std.debug.print(Ansi.Green ++ "{}\n" ++ Ansi.Reset, .{value});
    }

    pub fn debugStack(self: *Vm) void {
        std.debug.print("Stack: ", .{});
        for (self.stack.items, 0..) |item, i| {
            if (i != 0) std.debug.print(", ", .{});
            std.debug.print(Ansi.Cyan ++ "{}" ++ Ansi.Reset, .{item});
        }
        std.debug.print(Ansi.Dim ++ "{s}" ++ Ansi.Reset, .{if (self.stack.count() == 0) "(EMPTY)\n" else " (TOP)\n"});
    }
};
