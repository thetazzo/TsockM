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

pub fn screenClear() !void {
    std.log.warn("depricated", .{});
    const stdout = std.io.getStdOut().writer();
    try stdout.print("\x1B[2J\x1B[H", .{});
}
