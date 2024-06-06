const std = @import("std");
const server = @import("server.zig");

const SERVER_ADDRESS = "127.0.0.1"; // default address is local host
const SERVER_PORT = 6969; // default port

fn print_usage(program: []const u8) void {
    std.debug.print("{s}: <subcommand>\n", .{program});
    std.debug.print("SUBCOMMANDS:\n", .{});
    std.debug.print("    help ...................,,,,,,,,.. print program usage\n", .{});
    std.debug.print("    start <flag> ..................... start the server\n", .{});
    std.debug.print("        --addr <address> <port> ...... specify a custom address to the TsockM server (default: 127.0.0.1:6969)\n", .{});
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var argv = try std.process.argsWithAllocator(allocator);

    const program = argv.next().?;
    const subc = argv.next(); // subcommand

    if (subc) |subcommand| {
        if (std.mem.eql(u8, subcommand, "help")) {
            print_usage(program);
        } else if (std.mem.eql(u8, subcommand, "start")) {
            const subcommand_flag = argv.next(); 
            if (subcommand_flag) |sflag| {
            if (std.mem.eql(u8, sflag, "--addr")) {
                    const flag_addr_address = argv.next(); 
                    const flag_addr_port = argv.next(); 
                    if (flag_addr_address) |addr| {
                        if (flag_addr_port) |port| {
                            const port_u16 = try std.fmt.parseInt(u16, port, 10);
                            _ = try server.start(addr, port_u16);
                        } else {
                            _ = try server.start(addr, SERVER_PORT);
                        }
                    }
                } else {
                    std.log.err("unknown flag `{s}`", .{sflag});
                    print_usage(program);
                }
            } else {
                // use default values when no `--addr` is provided
                _ = try server.start(SERVER_ADDRESS, SERVER_PORT);
            }
        } 
    } else {
        std.log.err("missing subcommand!", .{});
        print_usage(program);
    }
}
