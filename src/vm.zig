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

pub const Vm = struct {
    allocator: Allocator,
    stack: Array(Value),
    chunk: Chunk,
    ip: usize,
    root: ?*Object = null,

    const Errror = error{
        StackUnderflow,
    };

    pub fn init(allocator: Allocator, chunk: Chunk) !Vm {
        return Vm{
            .allocator = allocator,
            .stack = try Array(Value).initCapacity(allocator, 1024),
            .chunk = chunk,
            .ip = 0,
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

    fn trackObject(self: *Vm, object: *Object) void {
        object.next = self.root;
        self.root = object;
    }

    fn stackPush(self: *Vm, value: Value) !void {
        try self.stack.push(value);
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
                    defer left.deinit();

                    try left.appendString(right);
                    const object = try Object.initString(self.allocator, left.buffer);
                    self.trackObject(object);

                    try self.stackPush(try Value.initObject(object));
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
        std.debug.print(" <- TOP\n", .{});
    }
};
