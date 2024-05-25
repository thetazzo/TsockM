const std = @import("std");
const print = std.debug.print;

pub fn start() !void {
    print("Server started\n", .{});
    print("Server closed\n", .{});
}
