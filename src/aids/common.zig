const std = @import("std");

// convert an integer to string
pub fn type_as_str(d: type) []const u8 {
    const allocator = std.heap.page_allocator;
    const peer_id = std.fmt.allocPrint(allocator, "{d}", .{d}) catch "format failed";
    return peer_id;
}

pub fn address_as_str(addr: std.net.Address) []const u8 {
    const allocator = std.heap.page_allocator;
    const addr_str = std.fmt.allocPrint(allocator, "{any}", .{addr}) catch "format failed";
    return addr_str;
}

pub fn assert(cnd: bool, opt_msg: ?[]const u8) void {
    if (!cnd) {
        if (opt_msg) |msg| {
            std.log.err("Assertion failed: {s}", .{msg});
        }
        @panic("assertion failed");
    }
}
