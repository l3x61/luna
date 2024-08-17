const std = @import("std");
const Allocator = std.mem.Allocator;

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

    pub fn trackObject(self: *Vm, object: *Object) *Object {
        object.next = self.root;
        self.root = object;
        return object;
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
                    // TODO: instead of deiniting the strings now, return an object and add it to the linked list of objects to save time ?
                    var right = try (try self.stackPop()).toString(self.allocator);
                    defer right.deinit();
                    var left = try (try self.stackPop()).toString(self.allocator);
                    defer left.deinit();
                    var string = String.init(self.allocator);
                    defer string.deinit();
                    try string.appendString(left);
                    try string.appendString(right);
                    const object = try Object.initString(self.allocator, string.buffer);
                    try self.stackPush(try Value.initObject(self.trackObject(object)));
                },
                .HALT => return,
            }
        }
    }

    pub fn debugStack(self: *Vm) void {
        std.debug.print("Stack | ", .{});
        for (self.stack.items, 0..) |item, i| {
            if (i != 0) {
                std.debug.print(", ", .{});
            }
            std.debug.print("{}", .{item});
        }
        std.debug.print(" <- TOP\n", .{});
    }
};
