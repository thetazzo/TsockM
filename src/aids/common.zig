const std = @import("std");

pub fn address_as_str(addr: std.net.Address) []const u8 {
    //std.log.warn("depricated! Just create a `*_str` prop in the structrure", .{});
    const allocator = std.heap.page_allocator;
    const addr_str = std.fmt.allocPrint(allocator, "{any}", .{addr}) catch "format failed";
    return addr_str;
}
