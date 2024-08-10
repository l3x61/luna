const std = @import("std");
const Allocator = std.mem.Allocator;

const Node = @import("node.zig").Node;
const Array = @import("array.zig").Array;
const Chunk = @import("chunk.zig").Chunk;
const OpCode = @import("chunk.zig").OpCode;
const Instruction = @import("chunk.zig").Instruction;
const Value = @import("value.zig").Value;

pub const Vm = struct {
    allocator: Allocator,
    stack: Array(Value),
    chunk: Chunk,
    ip: usize,

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
        for (self.stack.items) |*item| {
            item.deinit();
        }
        self.stack.deinit();
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
                .CONST => try self.stackPush(self.chunk.getConstant(instruction.index)),
                .POP => _ = try self.stackPop(),
                .ADD => {
                    const right = (try self.stackPop()).toNumber();
                    const left = (try self.stackPop()).toNumber();
                    try self.stackPush(Value.initNumber(left + right));
                },
                .SUB => {
                    const right = (try self.stackPop()).toNumber();
                    const left = (try self.stackPop()).toNumber();
                    try self.stackPush(Value.initNumber(left - right));
                },
                .MUL => {
                    const right = (try self.stackPop()).toNumber();
                    const left = (try self.stackPop()).toNumber();
                    try self.stackPush(Value.initNumber(left * right));
                },
                .POW => {
                    const right = (try self.stackPop()).toNumber();
                    const left = (try self.stackPop()).toNumber();
                    try self.stackPush(Value.initNumber(std.math.pow(f64, left, right)));
                },
                .DIV => {
                    const right = (try self.stackPop()).toNumber();
                    const left = (try self.stackPop()).toNumber();
                    try self.stackPush(Value.initNumber(left / right));
                },
                .MOD => {
                    const right = (try self.stackPop()).toNumber();
                    const left = (try self.stackPop()).toNumber();
                    try self.stackPush(Value.initNumber(@mod(left, right)));
                },
                .NEG => {
                    const value = (try self.stackPop()).toNumber();
                    try self.stackPush(Value.initNumber(-value));
                },
                .HALT => return,
            }
        }
    }

    pub fn printTop(self: *Vm) void {
        const top = self.stackPop() catch {
            std.debug.print("TOP: stack empty\n", .{});
            return;
        };
        std.debug.print("TOP: {}\n", .{top});
    }
};
