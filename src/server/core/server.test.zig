const std = @import("std");
const print = std.debug.print;
const sc = @import("server.zig");

const str_allocator = std.heap.page_allocator;

const hostname = "127.0.0.1";
const port = 6942;

const SILENT = false;
fn equalStr(s1: []const u8, s2: []const u8) bool {
    if (!SILENT) {
        print("                                         \n", .{});
        print("-----------------------------------------\n", .{});
        print("    expected: `{s}`\n", .{s1});
        print("    got: `{s}`\n", .{s2});
        print("-----------------------------------------\n", .{});
    }
    return std.mem.eql(u8, s1, s2);
}
fn equalEnum(comptime T: type, s1: T, s2: T) bool {
    if (!SILENT) {
        print("                                         \n", .{});
        print("-----------------------------------------\n", .{});
        print("    expected: `{s}`\n", .{@tagName(s1)});
        print("    got: `{s}`\n", .{@tagName(s2)});
        print("-----------------------------------------\n", .{});
    }
    return s1 == s2;
}
test "Server.init" {
    var tmp = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_allocator = tmp.allocator();
    const server = sc.Server.init(gpa_allocator, str_allocator, hostname, port, .DEV, "");
    try std.testing.expect(equalStr("127.0.0.1:6942", server.address_str));
}
