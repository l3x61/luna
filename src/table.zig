const std = @import("std");
const Allocator = std.mem.Allocator;

const Array = @import("array.zig").Array;
const Utils = @import("utils.zig");

pub fn Table(comptime Key: type, comptime Value: type) type {
    return struct {
        const Self = @This();
        const Pair = struct {
            key: Key,
            value: Value,
        };

        array: Array(Pair),
        compare: *const fn (Key, Key) bool,

        pub fn init(allocator: Allocator, compare: fn (Key, Key) bool) Self {
            return Self{
                .array = Array(Pair).init(allocator),
                .compare = compare,
            };
        }

        pub fn deinit(self: *Self) void {
            self.array.deinit();
        }

        pub fn set(self: *Self, key: Key, value: Value) !void {
            try self.array.push(Pair{
                .key = key,
                .value = value,
            });
        }

        pub fn get(self: *Self, key: Key) ?Value {
            const index = self.find(key) orelse return null;
            return self.array.items[index].value;
        }

        pub fn remove(self: *Self, key: Key) !void {
            const index = self.find(key) orelse return;
            try self.array.remove(index);
        }

        fn find(self: *Self, key: Key) ?usize {
            for (self.array.items, 0..) |pair, index| {
                if (self.compare(pair.key, key)) {
                    return index;
                }
            }
            return null;
        }
    };
}

test "table: init/deinit" {
    const allocator = std.testing.allocator;

    const Fns = struct {
        fn compare(a: u32, b: u32) bool {
            return a == b;
        }
    };

    var table = Table(u32, u32).init(allocator, Fns.compare);
    defer table.deinit();
}

test "table: set/get" {
    const allocator = std.testing.allocator;

    const Fns = struct {
        fn compare(a: u32, b: u32) bool {
            return a == b;
        }
    };

    var table = Table(u32, u32).init(allocator, Fns.compare);

    try table.set(1, 2);
    try table.set(2, 3);
    try table.set(399, 4222);

    try std.testing.expect(table.get(1) == 2);
    try table.remove(1);
    try std.testing.expect(table.get(1) == null);

    try std.testing.expect(table.get(2) == 3);
    try std.testing.expect(table.get(399) == 4222);
    try table.remove(2);
    try std.testing.expect(table.get(399) == 4222);

    defer table.deinit();
}
