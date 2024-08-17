const std = @import("std");
const Allocator = std.mem.Allocator;

const utils = @import("utils.zig");

pub const String = struct {
    buffer: []u8,
    capacity: usize,
    allocator: Allocator,

    pub const Error = error{
        OutOfMemory,
    };

    pub fn init(allocator: Allocator) String {
        return String{
            .buffer = &.{},
            .capacity = 0,
            .allocator = allocator,
        };
    }

    pub fn initLiteral(allocator: Allocator, literal: []const u8) !String {
        var string = String.init(allocator);
        try string.appendLiteral(literal);
        return string;
    }

    pub fn initString(allocator: Allocator, other: String) !String {
        var string = String.init(allocator);
        try string.append(other.buffer);
        return string;
    }

    pub fn initPrint(allocator: Allocator, comptime fmt: []const u8, args: anytype) !String {
        var string = String.init(allocator);
        try string.appendPrint(fmt, args);
        return string;
    }

    pub fn deinit(self: *String) void {
        if (self.capacity != 0) {
            self.allocator.free(self.buffer.ptr[0..self.capacity]);
            self.buffer = &.{};
            self.capacity = 0;
        }
    }

    pub fn clone(self: *String) !String {
        var new = self.allocator.alloc(u8, self.capacity) catch {
            return Error.OutOfMemory;
        };
        new.len = self.buffer.len;
        @memcpy(new, self.buffer);
        return String{
            .buffer = new,
            .capacity = self.capacity,
            .allocator = self.allocator,
        };
    }

    pub fn appendLiteral(self: *String, slice: []const u8) Error!void {
        while (self.capacity < self.buffer.len + slice.len) {
            try self.setCapacity(utils.nextPowerOf2(self.buffer.len + slice.len));
        }
        for (slice) |c| {
            self.buffer.ptr[self.buffer.len] = c;
            self.buffer.len += 1;
        }
    }

    pub fn appendString(self: *String, other: String) Error!void {
        try self.appendLiteral(other.buffer);
    }

    pub fn appendPrint(self: *String, comptime fmt: []const u8, args: anytype) Error!void {
        // TODO: implement a writer for String
        var list = std.ArrayList(u8).init(self.allocator);
        defer list.deinit();
        try list.writer().print(fmt, args);
        try self.appendLiteral(list.items);
    }

    pub fn equal(this: String, that: String) bool {
        return std.mem.eql(u8, this.buffer, that.buffer);
    }

    pub fn format(self: String, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        try writer.print("{s}", .{self.buffer});
    }

    fn setCapacity(self: *String, new_capacity: usize) Error!void {
        const old_length = self.buffer.len;
        self.buffer = self.allocator.realloc(self.buffer.ptr[0..self.capacity], new_capacity) catch {
            return Error.OutOfMemory;
        };
        self.capacity = new_capacity;
        self.buffer.len = old_length;
    }
};

test "string: init/deinit" {
    const allocator = std.testing.allocator;
    var string = String.init(allocator);
    string.deinit();
}

test "string: push" {
    const allocator = std.testing.allocator;
    var string = String.init(allocator);
    defer string.deinit();

    _ = try string.append("Hello");
    _ = try string.append(" ");
    _ = try string.append("World\n");

    std.debug.print("{s}", .{string.buffer});
}

test "string: print" {
    const allocator = std.testing.allocator;
    var string = String.init(allocator);
    defer string.deinit();

    _ = try string.print("Hello, {s} {d}!", .{ "World", 3.1415 });

    std.debug.print("{s}", .{string.buffer});
}
