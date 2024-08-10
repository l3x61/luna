const std = @import("std");
const Allocator = std.mem.Allocator;

const ArrayList = @import("std").ArrayList;
const String = @import("string.zig").String;

pub const Value = struct {
    tag: Tag,
    as: Union,

    const Tag = enum {
        Null,
        Boolean,
        Number,
        String,

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
        string: String,
    };

    pub const Error = error{
        DivisionBy0,
    };

    pub fn init() Value {
        return Value{ .tag = Tag.Null, .as = Union{ .null = {} } };
    }

    pub fn deinit(self: *Value) void {
        switch (self.tag) {
            .String => self.as.string.deinit(),
            else => {},
        }
    }

    pub fn initBoolean(value: bool) Value {
        return Value{ .tag = Tag.Boolean, .as = Union{ .boolean = value } };
    }

    pub fn initNumber(value: f64) Value {
        return Value{ .tag = Tag.Number, .as = Union{ .number = value } };
    }

    pub fn initString(allocator: Allocator, value: []const u8) !Value {
        return Value{
            .tag = Tag.String,
            .as = Union{
                .string = try String.initLiteral(allocator, value),
            },
        };
    }

    pub fn toBoolean(self: Value) bool {
        switch (self.tag) {
            .Null => return false,
            .Boolean => return self.as.boolean,
            .Number => return self.as.number != 0.0,
            .String => return self.as.string.items.len != 0,
        }
    }

    pub fn toNumber(self: Value) f64 {
        switch (self.tag) {
            .Null => return 0.0,
            .Boolean => return if (self.as.boolean) 1.0 else 0.0,
            .Number => return self.as.number,
            .String => {
                if (self.as.string.items.len == 0) {
                    return 0.0;
                } else {
                    return std.fmt.parseFloat(f64, self.as.string.items) catch {
                        return std.math.nan(f64);
                    };
                }
            },
        }
    }

    pub fn toString(self: Value, allocator: Allocator) !String {
        switch (self.tag) {
            .Null => return try String.initLiteral(allocator, "null"),
            .Boolean => return try String.initLiteral(allocator, if (self.as.boolean) "true" else "false"),
            .Number => return try String.initPrint(allocator, "{d}", .{self.as.number}),
            .String => return self.as.string.clone(),
        }
    }

    pub fn negate(right: Value) Value {
        return Value.initNumber(-right.toNumber());
    }

    pub fn add(left: Value, right: Value) Value {
        return Value.initNumber(left.toNumber() + right.toNumber());
    }

    pub fn subtract(left: Value, right: Value) Value {
        return Value.initNumber(left.toNumber() - right.toNumber());
    }

    pub fn multiply(left: Value, right: Value) Value {
        return Value.initNumber(left.toNumber() * right.toNumber());
    }

    pub fn power(left: Value, right: Value) Value {
        return Value.initNumber(std.math.pow(f64, left.toNumber(), right.toNumber()));
    }

    pub fn divide(left: Value, right: Value) !Value {
        if (right.toNumber() == 0.0) {
            return Error.DivisionBy0;
        }
        return Value.initNumber(left.toNumber() / right.toNumber());
    }

    pub fn modulo(left: Value, right: Value) !Value {
        if (right.toNumber() == 0.0) {
            return Error.DivisionBy0;
        }
        return Value.initNumber(@mod(left.toNumber(), right.toNumber()));
    }

    pub fn clone(self: *Value) Value {
        switch (self.tag) {
            .Null => return Value.init(),
            .Boolean => return Value.initBoolean(self.as.boolean),
            .Number => return Value.initNumber(self.as.number),
        }
    }

    pub fn equalStrict(left: Value, right: Value) bool {
        if (left.tag != right.tag) {
            return false;
        }
        switch (left.tag) {
            .Null => return true,
            .Boolean => return left.as.boolean == right.as.boolean,
            .Number => return left.as.number == right.as.number,
            .String => return std.mem.eql(u8, left.as.string.items, right.as.string.items),
        }
    }

    pub fn format(self: Value, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        switch (self.tag) {
            .Null => try writer.print("null", .{}),
            .Boolean => try writer.print("{s}", .{if (self.as.boolean) "true" else "false"}),
            .Number => try writer.print("{d}", .{self.as.number}),
            .String => try writer.print("{s}", .{self.as.string.items}),
        }
    }
};
