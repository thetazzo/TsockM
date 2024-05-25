const std = @import("std");
const server = @import("server.zig");

pub fn main() !void {
    const server_ = server.start();
    _ = try server_;
}
