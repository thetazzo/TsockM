const std = @import("std");

pub fn assert(cnd: bool, opt_msg: ?[]const u8) void {
    if (!cnd) {
        if (opt_msg) |msg| {
            std.log.err("Assertion failed: {s}", .{msg});
        }
        @panic("assertion failed");
    }
}
