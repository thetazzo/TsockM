const std = @import("std");

// TODO: accept allocator as parameter so that it can free the allocated string
// TOOD: fix fn name should be camelCase
pub fn address_as_str(addr: std.net.Address) []const u8 {
    //std.log.warn("depricated! Just create a `*_str` prop in the structrure", .{});
    const allocator = std.heap.page_allocator;
    const addr_str = std.fmt.allocPrint(allocator, "{any}", .{addr}) catch "format failed";
    return addr_str;
}
