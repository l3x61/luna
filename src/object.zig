const std = @import("std");
const Allocator = std.mem.Allocator;

const String = @import("string.zig").String;
const Vm = @import("vm.zig").Vm;

pub const Object = struct {
    tag: Tag,
    as: Union,
    allocator: Allocator,
    next: ?*Object = null,

    const Tag = enum {
        String,

        pub fn format(self: Tag, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
            _ = fmt;
            _ = options;
            try writer.print("'{s}'", .{@tagName(self)});
        }
    };

    const Union = union {
        string: String,
    };

    pub fn initString(allocator: Allocator, value: []const u8) !*Object {
        const object = try allocator.create(Object);
        object.* = Object{
            .tag = Tag.String,
            .as = Union{ .string = try String.initLiteral(allocator, value) },
            .allocator = allocator,
        };
        return object;
    }

    pub fn clone(self: *Object) !*Object {
        switch (self.tag) {
            .String => return initString(self.allocator, self.as.string.buffer),
        }
    }

    pub fn toBoolean(self: *Object) !bool {
        switch (self.tag) {
            .String => return false,
        }
    }

    pub fn toNumber(self: *Object) !f64 {
        switch (self.tag) {
            .String => return try std.fmt.parseFloat(f64, self.as.string.buffer),
        }
    }

    pub fn toString(self: *Object) !String {
        switch (self.tag) {
            .String => return self.as.string.clone(),
        }
    }

    pub fn deinit(self: *Object) void {
        switch (self.tag) {
            .String => self.as.string.deinit(),
        }
        self.allocator.destroy(self);
    }

    pub fn equal(left: *Object, right: *Object) bool {
        if (left.tag != right.tag) {
            return false;
        }
        switch (left.tag) {
            .String => return String.equal(left.as.string, right.as.string),
        }
    }

    pub fn format(self: Object, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        switch (self.tag) {
            .String => try writer.print("{s}", .{self.as.string.buffer}),
        }
    }
};
