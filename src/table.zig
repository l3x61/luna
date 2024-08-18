const std = @import("std");
const Allocator = std.mem.Allocator;

const Array = @import("array.zig").Array;
const Value = @import("value.zig").Value;
const Utils = @import("utils.zig");

pub const Table = struct {
    pub const Entry = struct {
        key: Value,
        value: Value,
    };

    entries: Array(Entry),

    pub fn init(allocator: *Allocator) Table {
        return Table{
            .entries = Array.init(allocator, Entry, 0),
        };
    }

    pub fn deinit(self: *Table) void {
        self.entries.deinit();
    }
};
