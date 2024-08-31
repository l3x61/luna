const std = @import("std");
const Allocator = std.mem.Allocator;

const Value = @import("value.zig").Value;
const Utils = @import("utils.zig");

const primes = [_]usize{ 0, 2, 5, 11, 17, 37, 67, 131, 257, 521, 1031, 2053, 4099, 8209, 16411, 32771, 65537, 131101, 262147, 524309, 1048583, 2097169, 4194319, 8388617, 16777259, 33554467, 67108879, 134217757, 268435459, 536870923, 1073741827, 2147483659, 4294967311, 8589934609, 17179869209, 34359738421, 68719476767, 137438953481, 274877906951, 549755813911, 1099511627791, 2199023255579, 4398046511119, 8796093022237, 17592186044423, 35184372088891, 70368744177679, 140737488355333, 281474976710677, 562949953421381, 1125899906842679, 2251799813685269, 4503599627370517, 9007199254740997, 18014398509482143, 36028797018963971, 72057594037928017, 144115188075855881, 288230376151711813, 576460752303423619, 1152921504606847009, 2305843009213693967, 4611686018427388039, 9223372036854775837 };

pub const Table = struct {
    pub const Entry = struct {
        key: ?Value,
        value: ?Value,
    };

    allocator: Allocator,
    entries: []Entry,
    count: usize,
    prime_index: u6,

    pub fn init(allocator: Allocator) Table {
        return Table{
            .allocator = allocator,
            .entries = &.{},
            .count = 0,
            .prime_index = 0,
        };
    }

    pub fn deinit(self: *Table) void {
        if (self.entries.len == 0) return;
        self.allocator.free(self.entries.ptr[0..self.entries.len]);
        self.entries = &.{};
        self.count = 0;
    }

    pub fn set(self: *Table, key: Value, value: Value) !bool {
        const count = @as(f64, @floatFromInt(self.count));
        const capacity = @as(f64, @floatFromInt(self.entries.len));
        if (count + 1 > capacity * 0.75) try self.resize();
        var entry = find(self.entries, key);
        const is_new_key = entry.key == null;
        if (is_new_key) entry.key = key;
        if (entry.value) |_| entry.value.?.deinit();
        entry.value = value;
        if (is_new_key) self.count += 1;
        return is_new_key;
    }

    pub fn get(self: *Table, key: Value) ?Value {
        if (self.entries.len == 0) return null;
        const entry = find(self.entries, key);
        if (entry.key) |_| return entry.value;
        return null;
    }

    pub fn remove(self: *Table, key: Value) bool {
        if (self.entries.len == 0) return false;
        var entry = find(self.entries, key);
        if (entry.key == null) return false;
        entry.key.?.deinit();
        entry.key = null;
        entry.value.?.deinit();
        return true;
    }

    pub fn debug(self: Table) void {
        for (self.entries) |entry| {
            if (entry.key == null) continue;
            std.debug.print("{}: {}\n", .{ entry.key.?, entry.value.? });
        }
    }

    fn find(entries: []Entry, key: Value) *Entry {
        var index = key.hash() % entries.len;
        var tombstone: ?*Entry = null; // key == null & value != null
        while (true) : (index = (index + 1) % entries.len) {
            const entry = &entries[index];
            if (entry.key) |entry_key| {
                if (Value.compare(entry_key, key)) return entry;
            } else {
                if (entry.value) |_| {
                    if (tombstone == null) tombstone = entry;
                } else {
                    return if (tombstone) |ts| ts else entry;
                }
            }
        }
    }

    fn resize(self: *Table) !void {
        self.prime_index += 1;
        const new_entries = try self.allocator.alloc(Entry, primes[self.prime_index]);
        for (new_entries) |*entry| entry.* = Entry{ .key = null, .value = null };
        self.count = 0;
        for (self.entries) |*entry| {
            if (entry.key) |entry_key| {
                const new_entry = find(new_entries, entry_key);
                new_entry.key = entry.key;
                new_entry.value = entry.value;
                self.count += 1;
            }
        }
        self.allocator.free(self.entries.ptr[0..self.entries.len]);
        self.entries = new_entries;
    }
};

test "table: in/deinit" {
    const allocator = std.testing.allocator;
    var table = Table.init(allocator);
    table.deinit();
}

test "table: in/deinit set get remove" {
    const allocator = std.testing.allocator;
    var table = Table.init(allocator);
    defer table.deinit();

    try std.testing.expect(try table.set(Value.initNull(), Value.initNumber(1.0)) == true);
    try std.testing.expect(try table.set(Value.initNull(), Value.initNumber(1.0)) == false);

    const val = table.get(Value.initNull());
    try std.testing.expect(Value.compare(val.?, Value.initNumber(1.0)));

    try std.testing.expect(table.remove(Value.initNull()) == true);
    try std.testing.expect(table.remove(Value.initNull()) == false);
}
