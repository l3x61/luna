const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Value = struct {
    tag: Tag,
    as: Union,

    const Tag = enum {
        Null,
        Boolean,
        Number,
    };

    const Union = union {
        null: void,
        boolean: bool,
        number: f64,
    };

    pub const Error = error{
        DivisionBy0,
    };

    pub fn init() Value {
        return Value{ .tag = Tag.Null, .as = Union{ .null = {} } };
    }

    pub fn initBoolean(value: bool) Value {
        return Value{ .tag = Tag.Boolean, .as = Union{ .boolean = value } };
    }

    pub fn initNumber(value: f64) Value {
        return Value{ .tag = Tag.Number, .as = Union{ .number = value } };
    }

    pub fn toBoolean(self: Value) bool {
        switch (self.tag) {
            .Null => return false,
            .Boolean => return self.as.boolean,
            .Number => return self.as.number != 0.0,
        }
    }

    pub fn toNumber(self: Value) f64 {
        switch (self.tag) {
            .Null => return 0.0,
            .Boolean => return if (self.as.boolean) 1.0 else 0.0,
            .Number => return self.as.number,
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

    pub fn debug(self: Value) void {
        switch (self.tag) {
            .Null => std.debug.print("null", .{}),
            .Boolean => std.debug.print("{s}", .{if (self.as.boolean) "true" else "false"}),
            .Number => std.debug.print("{d}", .{self.as.number}),
        }
    }
};