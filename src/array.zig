const std = @import("std");
const Allocator = std.mem.Allocator;

const utils = @import("utils.zig");

pub fn Array(comptime Type: type) type {
    return struct {
        items: []Type,
        capacity: usize,
        allocator: Allocator,

        const Self = @This();

        pub const Error = error{
            OutOfMemory,
            OutOfBounds,
        };

        pub fn init(allocator: Allocator) Self {
            return Self{
                .items = &.{},
                .capacity = 0,
                .allocator = allocator,
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
            if (self.items.len != 0) return self.items.ptr[self.items.len - 1];
            return null;
        }

        pub fn pop(self: *Self) ?Type {
            if (self.items.len == 0) return null;
            self.items.len -= 1;
            return self.items.ptr[self.items.len];
        }

        pub fn get(self: *const Self, index: usize) ?Type {
            if (index >= self.items.len) return null;
            return self.items.ptr[index];
        }

        pub fn set(self: *Self, item: Type, index: usize) Error!void {
            if (index >= self.items.len) return Error.OutOfBounds;
            self.items.ptr[index] = item;
        }

        pub fn insert(self: *Self, item: Type, index: usize) Error!void {
            if (index > self.items.len) return Error.OutOfBounds;
            if (self.items.len + 1 >= self.capacity) try self.doubleCapacity();
            for (self.items, self.items.len..index) |current, i| self.items.ptr[i + 1] = current;
            self.items.ptr[index] = item;
            self.items.len += 1;
        }

        pub fn remove(self: *Self, index: usize) Error!void {
            if (index >= self.items.len) return Error.OutOfBounds;
            for (index..self.items.len) |i| self.items.ptr[i] = self.items.ptr[i + 1];
            self.items.len -= 1;
        }

        pub fn searchLinear(self: *Self, item: Type, compare: fn (Type, Type) bool) ?usize {
            for (self.items, 0..) |current, index| if (compare(current, item)) return index;
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
            self.items = self.allocator.realloc(self.items.ptr[0..self.capacity], new_capacity) catch {
                return Error.OutOfMemory;
            };
            self.capacity = new_capacity;
            self.items.len = old_length;
        }
    };
}

test "array: init/deinit" {
    const allocator = std.testing.allocator;
    var array = Array(i32).init(allocator);
    array.deinit();
}

test "array: push" {
    const allocator = std.testing.allocator;
    var array = Array(i32).init(allocator);
    defer array.deinit();

    const expected = [_]i32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33 };

    for (expected) |item| {
        try array.push(item);
    }

    for (0..expected.len) |i| {
        try std.testing.expect(expected[i] == array.items[i]);
    }
}
