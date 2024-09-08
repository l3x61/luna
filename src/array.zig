const std = @import("std");
const Allocator = std.mem.Allocator;

const utils = @import("utils.zig");

pub fn Array(comptime Type: type) type {
    return struct {
        allocator: Allocator,
        items: []Type,
        capacity: usize,

        const Self = @This();

        pub const Error = error{
            OutOfMemory,
            OutOfBounds,
            Underflow,
        };

        pub fn init(allocator: Allocator) Self {
            return Self{
                .allocator = allocator,
                .items = &.{},
                .capacity = 0,
            };
        }

        pub fn initCapacity(allocator: Allocator, capacity: usize) Error!Self {
            var self = Self.init(allocator);
            const new_capacity = if (utils.isPowerOf2(capacity)) capacity else utils.nextPowerOf2(capacity);
            self.items = self.allocator.realloc(self.items.ptr[0..self.capacity], new_capacity) catch return Error.OutOfMemory;
            self.items.len = 0;
            self.capacity = new_capacity;
            return self;
        }

        pub fn deinit(self: *Self) void {
            if (self.capacity == 0) return;
            self.allocator.free(self.items.ptr[0..self.capacity]);
            self.items = &.{};
            self.capacity = 0;
        }

        pub fn push(self: *Self, item: Type) Error!void {
            if (self.items.len + 1 >= self.capacity) try self.doubleCapacity();
            self.items.ptr[self.items.len] = item;
            self.items.len += 1;
        }

        pub fn peek(self: *const Self) ?Type {
            if (self.items.len != 0) return self.items.ptr[self.items.len - 1] else return null;
        }

        pub fn pop(self: *Self) ?Type {
            if (self.items.len == 0) return null;
            self.items.len -= 1;
            return self.items.ptr[self.items.len];
        }

        pub fn popN(self: *Self, n: usize) !void {
            if (self.items.len == 0 and n > 0 or self.items.len -% n > self.items.len) return Error.Underflow;
            self.items.len -= n;
        }

        pub fn set(self: *Self, index: usize, item: Type) Error!void {
            if (index >= self.items.len) return Error.OutOfBounds;
            self.items.ptr[index] = item;
        }

        pub fn get(self: *const Self, index: usize) ?Type {
            if (index >= self.items.len) return null else return self.items.ptr[index];
        }

        pub fn searchLinearIndex(self: *Self, item: Type, compare: fn (Type, Type) bool) ?usize {
            for (self.items, 0..) |current, index| if (compare(current, item)) return index;
            return null;
        }

        pub fn searchLinearReverseIndex(self: *Self, item: Type, compare: fn (Type, Type) bool) ?usize {
            var index: usize = self.items.len;
            while (index > 0) {
                index -= 1;
                if (compare(self.items[index], item)) return index;
            }
            return null;
        }

        pub fn count(self: *const Self) usize {
            return self.items.len;
        }

        fn doubleCapacity(self: *Self) Error!void {
            const old_length = self.items.len;
            const new_capacity = switch (self.capacity) {
                0 => 1,
                std.math.maxInt(usize) => return Error.OutOfMemory,
                else => self.capacity * 2,
            };
            self.items = self.allocator.realloc(self.items.ptr[0..self.capacity], new_capacity) catch return Error.OutOfMemory;
            self.capacity = new_capacity;
            self.items.len = old_length;
        }
    };
}
