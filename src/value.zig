const std = @import("std");
const Allocator = std.mem.Allocator;

const Object = @import("object.zig").Object;
const String = @import("string.zig").String;
const Vm = @import("vm.zig").Vm;

const sipHash = @import("siphash.zig").sipHash24;

pub const Value = struct {
    tag: Tag,
    as: Union,

    const Tag = enum {
        Null,
        Boolean,
        Number,
        Object,
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

    pub fn tagName(value: Value) []const u8 {
        return switch (value.tag) {
            .Object => @tagName(value.as.object.tag),
            else => @tagName(value.tag),
        };
    }

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
        if (left.tag != right.tag) return false;
        switch (left.tag) {
            .Null => return true,
            .Boolean => return left.as.boolean == right.as.boolean,
            .Number => return left.as.number == right.as.number,
            .Object => return Object.compare(left.as.object, right.as.object),
        }
    }

    pub fn hash(self: Value) u64 {
        switch (self.tag) {
            .Object => return self.as.object.hash(),
            else => return sipHash(std.mem.asBytes(&self)),
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

//test "value: hash" {
//    const allocator = std.testing.allocator;
//    const null1 = Value.initNull();
//    const null2 = Value.initNull();
//    const bool11 = Value.initBoolean(true);
//    const bool12 = Value.initBoolean(true);
//    const bool21 = Value.initBoolean(false);
//    const bool22 = Value.initBoolean(false);
//    const num11 = Value.initNumber(1.0);
//    const num12 = Value.initNumber(1.0);
//    const num21 = Value.initNumber(2.0);
//    const num22 = Value.initNumber(2.0);
//    var str11 = try Value.initObjectStringLiteral(allocator, "hello");
//    defer str11.deinit();
//    var str12 = try Value.initObjectStringLiteral(allocator, "hello");
//    defer str12.deinit();
//    var str21 = try Value.initObjectStringLiteral(allocator, "world");
//    defer str21.deinit();
//    var str22 = try Value.initObjectStringLiteral(allocator, "world");
//    defer str22.deinit();
//    // std.debug.print("{x}\n", .{null1.hash()});
//    // std.debug.print("{x}\n", .{null2.hash()});
//    // std.debug.print("{x}\n", .{bool11.hash()});
//    // std.debug.print("{x}\n", .{bool12.hash()});
//    // std.debug.print("{x}\n", .{bool21.hash()});
//    // std.debug.print("{x}\n", .{bool22.hash()});
//    // std.debug.print("{x}\n", .{num11.hash()});
//    // std.debug.print("{x}\n", .{num12.hash()});
//    // std.debug.print("{x}\n", .{num21.hash()});
//    // std.debug.print("{x}\n", .{num22.hash()});
//    // std.debug.print("{x}\n", .{str11.hash()});
//    // std.debug.print("{x}\n", .{str12.hash()});
//    // std.debug.print("{x}\n", .{str21.hash()});
//    // std.debug.print("{x}\n", .{str22.hash()});
//    std.debug.assert(str11.hash() == str12.hash());
//    std.debug.assert(str21.hash() == str22.hash());
//    std.debug.assert(null1.hash() == null2.hash());
//    std.debug.assert(bool11.hash() == bool12.hash());
//    std.debug.assert(bool21.hash() == bool22.hash());
//    std.debug.assert(num11.hash() == num12.hash());
//    std.debug.assert(num21.hash() == num22.hash());
//    std.debug.assert(str11.hash() != str21.hash());
//    std.debug.assert(str11.hash() != null1.hash());
//    std.debug.assert(str11.hash() != bool11.hash());
//    std.debug.assert(str11.hash() != num11.hash());
//}
