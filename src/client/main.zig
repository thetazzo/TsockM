const std = @import("std");
const client = @import("client.zig");

const SERVER_ADDRESS = "127.0.0.1"; // default address is local host
const SERVER_PORT = 6969; // default port

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var argv = try std.process.argsWithAllocator(allocator);

    _ = argv.next().?; // program
    const flag_1 = argv.next(); // -addr

    if (flag_1) |flag_addr| {
        if (std.mem.eql(u8, flag_addr, "-addr")) {
            const flag_addr_address = argv.next(); // - addr [address]
            const flag_addr_port = argv.next(); // - addr [address] [port]
            if (flag_addr_address) |addr| {
                if (flag_addr_port) |port| {
                    const port_u16 = try std.fmt.parseInt(u16, port, 10);
                    _ = try client.start(addr, port_u16);
                } else {
                    _ = try client.start(addr, SERVER_PORT);
                }
            }
        } else {
            std.log.err("unknown flag `{s}`\n", .{flag_addr});
        }
    } else {
        // use default values when no `-addr` is provided
        _ = try client.start(SERVER_ADDRESS, SERVER_PORT);
    }
}
