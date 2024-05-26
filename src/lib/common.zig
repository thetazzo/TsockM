const std = @import("std");

// convert an integer to string
pub fn usize_to_str(d: usize) []const u8 {
    const allocator = std.heap.page_allocator;
    const peer_id = std.fmt.allocPrint(allocator, "{d}", .{d}) catch "format failed";
    return peer_id;
}
