const std = @import("std");
const Allocator = std.mem.Allocator;

const Object = @import("object.zig").Object;
const String = @import("string.zig").String;
const Vm = @import("vm.zig").Vm;

pub const Value = struct {
    tag: Tag,
    as: Union,

    const Tag = enum {
        Null,
        Boolean,
        Number,
        Object,

        pub fn format(self: Tag, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
            _ = fmt;
            _ = options;
            try writer.print("{s}", .{@tagName(self)});
        }
    };

    const Union = union {
        null: void,
        boolean: bool,
        number: f64,
        object: *Object,
    };

    pub const Error = error{
        DivisionBy0,
    };

    pub fn initNull() Value {
        return Value{ .tag = Tag.Null, .as = Union{ .null = {} } };
    }

    pub fn initBoolean(value: bool) Value {
        return Value{ .tag = Tag.Boolean, .as = Union{ .boolean = value } };
    }

    pub fn initNumber(value: f64) Value {
        return Value{ .tag = Tag.Number, .as = Union{ .number = value } };
    }

    pub fn initObject(value: *Object) !Value {
        return Value{ .tag = Tag.Object, .as = Union{ .object = value } };
    }

    pub fn initObjectString(allocator: Allocator, string: String) !Value {
        return Value{ .tag = Tag.Object, .as = Union{ .object = try Object.initString(allocator, string) } };
    }

    pub fn initObjectStringLiteral(allocator: Allocator, literal: []const u8) !Value {
        return Value{ .tag = Tag.Object, .as = Union{ .object = try Object.initStringLiteral(allocator, literal) } };
    }

    pub fn deinit(self: *Value) void {
        switch (self.tag) {
            .Object => self.as.object.deinit(),
            else => {},
        }
    }

    pub fn clone(self: Value) !Value {
        switch (self.tag) {
            .Null => return self,
            .Boolean => return self,
            .Number => return self,
            .Object => return initObject(try self.as.object.clone()),
        }
    }

    pub fn toBoolean(self: Value) bool {
        switch (self.tag) {
            .Null => return false,
            .Boolean => return self.as.boolean,
            .Number => return self.as.number != 0.0,
            .Object => return self.as.object.toBoolean(),
        }
    }

    pub fn toNumber(self: Value) !f64 {
        switch (self.tag) {
            .Null => return 0.0,
            .Boolean => return if (self.as.boolean) 1.0 else 0.0,
            .Number => return self.as.number,
            .Object => return self.as.object.toNumber(),
        }
    }

    pub fn toString(self: Value, allocator: Allocator) !String {
        switch (self.tag) {
            .Null => return String.initLiteral(allocator, "null"),
            .Boolean => return String.initLiteral(allocator, if (self.as.boolean) "true" else "false"),
            .Number => return String.initPrint(allocator, "{d}", .{self.as.number}),
            .Object => return self.as.object.toString(),
        }
    }

    pub fn compare(left: Value, right: Value) bool {
        if (left.tag != right.tag) {
            return false;
        }
        switch (left.tag) {
            .Null => return true,
            .Boolean => return left.as.boolean == right.as.boolean,
            .Number => return left.as.number == right.as.number,
            .Object => return Object.compare(left.as.object, right.as.object),
        }
    }

    pub fn format(self: Value, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        switch (self.tag) {
            .Null => try writer.print("null", .{}),
            .Boolean => try writer.print("{s}", .{if (self.as.boolean) "true" else "false"}),
            .Number => try writer.print("{d}", .{self.as.number}),
            .Object => try writer.print("'{}'", .{self.as.object}),
        }
    }
};
