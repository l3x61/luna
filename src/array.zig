const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn Array(comptime Type: type) type {
    return struct {
        items: []Type,
        capacity: usize,
        allocator: Allocator,

        const Self = @This();

        pub const Error = error{
            OutOfMemory,
        };

        pub fn init(allocator: Allocator) Self {
            return Self{
                .items = &.{},
                .capacity = 0,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            if (self.capacity != 0) {
                self.allocator.free(self.items.ptr[0..self.capacity]);
                self.items = &.{};
                self.capacity = 0;
            }
        }

        pub fn push(self: *Self, item: Type) Error!void {
            if (self.items.len + 1 >= self.capacity) {
                try self.doubleCapacity();
            }
            self.items.ptr[self.items.len] = item;
            self.items.len += 1;
        }

        pub fn peek(self: *Self) ?Type {
            if (self.items.len != 0) {
                return self.items.ptr[self.items.len - 1];
            }
            return null;
        }

        pub fn pop(self: *Self) ?Type {
            if (self.items.len != 0) {
                self.items.len -= 1;
                return self.items.ptr[self.items.len];
            }
            return null;
        }

        pub fn find(self: *Self, item: Type, compare: fn (Type, Type) bool) ?usize {
            for (self.items, 0..) |current, i| {
                if (compare(current, item)) {
                    return i;
                }
            }
            return null;
        }

        pub fn first(self: *const Self) ?Type {
            if (self.items.len != 0) {
                return self.items[0];
            }
            return null;
        }

        pub fn last(self: *const Self) ?Type {
            if (self.items.len != 0) {
                return self.items[self.items.len - 1];
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
