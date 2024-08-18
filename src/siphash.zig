// Copyright 2012-2024 JP Aumasson
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

const std = @import("std");

inline fn init(state: *[4]u64, key: [2]u64) void {
    state[0] = 0x736f6d6570736575 ^ key[0];
    state[1] = 0x646f72616e646f6d ^ key[1];
    state[2] = 0x6c7967656e657261 ^ key[0];
    state[3] = 0x7465646279746573 ^ key[1];
}

inline fn compress(state: *[4]u64, m: u64) void {
    state[3] ^= m;
    round(state);
    round(state);
    state[0] ^= m;
}

inline fn finalize(state: *[4]u64) void {
    state[2] ^= 0xff;
    round(state);
    round(state);
    round(state);
    round(state);
}

inline fn round(state: *[4]u64) void {
    state[0] +%= state[1];
    state[1] = std.math.rotl(u64, state[1], 13);
    state[1] ^= state[0];
    state[0] = std.math.rotl(u64, state[0], 32);
    state[2] +%= state[3];
    state[3] = std.math.rotl(u64, state[3], 16);
    state[3] ^= state[2];
    state[0] +%= state[3];
    state[3] = std.math.rotl(u64, state[3], 21);
    state[3] ^= state[0];
    state[2] +%= state[1];
    state[1] = std.math.rotl(u64, state[1], 17);
    state[1] ^= state[2];
    state[2] = std.math.rotl(u64, state[2], 32);
}

inline fn u8ToU64(data: []const u8, i: usize) u64 {
    return @as(u64, data[i]) |
        @as(u64, data[i + 1]) << 8 |
        @as(u64, data[i + 2]) << 16 |
        @as(u64, data[i + 3]) << 24 |
        @as(u64, data[i + 4]) << 32 |
        @as(u64, data[i + 5]) << 40 |
        @as(u64, data[i + 6]) << 48 |
        @as(u64, data[i + 7]) << 56;
}

pub fn sipHash24(data: []const u8, key: [2]u64) u64 {
    var state: [4]u64 = undefined;
    init(&state, key);
    var m: u64 = undefined;
    var i: usize = 0;
    while (i + 8 <= data.len) : (i += 8) {
        m = u8ToU64(data, i);
        compress(&state, m);
    }
    var j: usize = 0;
    m = 0;
    while (j < data.len - i) : (j += 1) m |= @as(u64, data[i + j]) << @intCast(j * 8);
    m |= @as(u64, data.len << 56);
    compress(&state, m);
    finalize(&state);
    return state[0] ^ state[1] ^ state[2] ^ state[3];
}

// testing against https://github.com/WeblateOrg/siphashc
//
// from siphashc import siphash
// siphash(key, data)

test "sipHash24 test1" {
    // hex(siphash(bytes.fromhex('00000000000000000000000000000000'), ""))
    const key = [2]u64{ 0x0000000000000000, 0x0000000000000000 };
    var timer = try std.time.Timer.start();
    const result = sipHash24("", key);
    const elapsed = @as(f64, @floatFromInt(timer.read()));
    std.debug.print("took {d:.3}ms\n", .{elapsed / std.time.ns_per_ms});
    std.debug.assert(result == 0x1e924b9d737700d7);
}

test "sipHash24 test2" {
    // hex(siphash(bytes.fromhex('00000000000000000000000000000000'), "helloworld!!!"))
    const key = [2]u64{ 0x0000000000000000, 0x0000000000000000 };
    var timer = try std.time.Timer.start();
    const result = sipHash24("helloworld!!!", key);
    const elapsed = @as(f64, @floatFromInt(timer.read()));
    std.debug.print("took {d:.3}ms\n", .{elapsed / std.time.ns_per_ms});
    std.debug.assert(result == 0x4b8e02f4c284fd68);
}

test "sipHash24 test3" {
    // hex(siphash(bytes.fromhex('ff0000000000000000000000000000ff'), ""))
    const key = [2]u64{ 0x00000000000000ff, 0xff00000000000000 };
    var timer = try std.time.Timer.start();
    const result = sipHash24("", key);
    const elapsed = @as(f64, @floatFromInt(timer.read()));
    std.debug.print("took {d:.3}ms\n", .{elapsed / std.time.ns_per_ms});
    std.debug.assert(result == 0x96e2850df6340c78);
}

test "sipHash24 lorem ipsum" {
    // hex(siphash(bytes.fromhex('ff0000000000000000000000000000ff'), "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.")))
    const key = [2]u64{ 0x00000000000000ff, 0xff00000000000000 };
    var timer = try std.time.Timer.start();
    const result = sipHash24("Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.", key);
    const elapsed = @as(f64, @floatFromInt(timer.read()));
    std.debug.print("took {d:.3}ms\n", .{elapsed / std.time.ns_per_ms});
    std.debug.assert(result == 0xd7587fe6f8ccd10d);
}
