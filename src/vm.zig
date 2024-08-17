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
const Globals = @import("globals.zig").Globals;

pub const Vm = struct {
    allocator: Allocator,
    stack: Array(Value),
    chunk: Chunk,
    ip: usize,
    root: ?*Object = null,
    globals: *Globals,

    const Errror = error{
        StackUnderflow,
    };

    pub fn init(allocator: Allocator, chunk: Chunk, globals: *Globals) !Vm {
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

    pub fn run(self: *Vm) !void {
        while (true) {
            const instruction = self.chunk.getInstruction(self.ip);
            self.ip = instruction.next;
            switch (instruction.opcode) {
                .CONST => {
                    try self.stackPush(self.chunk.getConstant(instruction.index));
                },
                .POP => _ = try self.stackPop(),
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
                .SETG => {
                    var key = try (try self.stackPop()).clone();
                    const value = try (try self.stackPeek()).clone();
                    try self.globals.set(&key, value);
                },
                .GETG => {
                    var key = try (try self.stackPop()).clone();
                    defer key.deinit();
                    const entry = self.globals.get(key);
                    try self.stackPush(if (entry) |e| e.value else Value.init());
                },
                .HALT => return,
            }
        }
    }

    pub fn debugStack(self: *Vm) void {
        std.debug.print("Stack: ", .{});
        for (self.stack.items, 0..) |item, i| {
            if (i != 0) {
                std.debug.print(", ", .{});
            }
            std.debug.print(Ansi.Cyan ++ "{}" ++ Ansi.Reset, .{item});
        }
        std.debug.print("{s}", .{if (self.stack.count() == 0) "> EMPTY <\n" else " <- TOP\n"});
    }
};
