const std = @import("std");
const client = @import("client.zig");

pub fn main() !void {
    _ = try client.start();
}
