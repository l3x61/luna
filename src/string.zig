const std = @import("std");
const Allocator = std.mem.Allocator;

pub const String = struct {
    items: []u8,
    capacity: usize,
    allocator: Allocator,

    pub const Error = error{
        OutOfMemory,
    };

    pub fn init(allocator: Allocator) String {
        return String{
            .items = &.{},
            .capacity = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *String) void {
        if (self.capacity != 0) {
            self.allocator.free(self.items.ptr[0..self.capacity]);
            self.items = &.{};
            self.capacity = 0;
        }
    }

    pub fn clone(self: *String) !String {
        var new = self.allocator.alloc(u8, self.capacity) catch {
            return Error.OutOfMemory;
        };
        new.len = self.items.len;
        @memcpy(new, self.items);
        return String{
            .items = new,
            .capacity = self.capacity,
            .allocator = self.allocator,
        };
    }

    pub fn append(self: *String, slice: []const u8) Error!void {
        while (self.capacity < self.items.len + slice.len) {
            // TODO: find a constant time algo
            try self.doubleCapacity();
        }
        for (slice) |c| {
            self.items.ptr[self.items.len] = c;
            self.items.len += 1;
        }
    }

    fn doubleCapacity(self: *String) Error!void {
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

test "array: init/deinit" {
    const allocator = std.testing.allocator;
    var string = String.init(allocator);
    string.deinit();
}

test "array: push" {
    const allocator = std.testing.allocator;
    var string = String.init(allocator);
    defer string.deinit();

    try string.append("Hello");
    try string.append(" ");
    try string.append("World");

    std.debug.print("{s}", .{string.items});
}