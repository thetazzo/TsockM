const std = @import("std");
const lib = @import("lib");
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
    
    var server_addr: []const u8 = SERVER_ADDRESS; 
    var server_port: u16 = SERVER_PORT; 
    const log_level: lib.Logging.Level = lib.Logging.Level.COMPACT; 

    if (subc) |subcommand| {
        if (std.mem.eql(u8, subcommand, "help")) {
            print_usage(program);
        } else if (std.mem.eql(u8, subcommand, "start")) {
            if (argv.next()) |arg| {
                if (std.mem.eql(u8, arg, "--addr")) {
                    const opt_ip = argv.next(); 
                    if (opt_ip) |ip| {
                        var splits = std.mem.splitScalar(u8, ip, ':');
                        if (splits.next()) |hostname| {
                            if (splits.next()) |port| {
                                const port_u16 = try std.fmt.parseInt(u16, port, 10);
                                server_port = port_u16;
                            }
                            server_addr = hostname;
                        } 
                    } else {
                        std.log.err("Missing server ip address", .{});
                        print_usage(program);
                        return;
                    }
                } else {
                    std.log.err("unknown flag `{s}`", .{arg});
                    print_usage(program);
                }
            } 
            _ = try server.start(server_addr, server_port, log_level);
        } 
    } else {
        std.log.err("missing subcommand!", .{});
        print_usage(program);
    }
}
