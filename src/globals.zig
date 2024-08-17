const std = @import("std");
const Allocator = std.mem.Allocator;

const Array = @import("array.zig").Array;
const Value = @import("value.zig").Value;
const Utils = @import("utils.zig");

pub const Globals = struct {
    entries: Array(Entry),

    const Entry = struct {
        key: Value,
        value: Value,
    };

    pub fn init(allocator: Allocator) Globals {
        return Globals{ .entries = Array(Entry).init(allocator) };
    }

    pub fn deinit(self: *Globals) void {
        self.entries.deinit();
    }

    pub fn get(self: *Globals, key: Value) ?*Entry {
        for (self.entries.items) |*entry| {
            if (Value.compare(key, entry.key)) return entry;
        }
        return null;
    }

    pub fn set(self: *Globals, key: *Value, value: Value) !void {
        if (self.get(key.*)) |entry| {
            entry.value.deinit();
            entry.value = value;
            key.deinit(); // lets keep the old key
        } else {
            try self.entries.push(Entry{ .key = key.*, .value = value });
        }
    }

    pub fn remove(self: *Globals, key: Value) void {
        if (self.entries.searchLinear(key, Value.compare)) |index| {
            self.entries.remove(index) catch unreachable;
        }
    }

    pub fn debug(self: *Globals) void {
        for (self.entries.items) |entry| {
            std.debug.print("{} -> {}\n", .{ entry.key, entry.value });
        }
    }
};
