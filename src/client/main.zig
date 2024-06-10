const std = @import("std");
const client = @import("client.zig");

const SERVER_ADDRESS = "127.0.0.1"; // default address is local host
const SERVER_PORT = 6969; // default port

fn print_usage(program: []const u8) void {
    std.debug.print("{s}: <subcommand>\n", .{program});
    std.debug.print("SUBCOMMANDS:\n", .{});
    std.debug.print("    help ............................. print program usage\n", .{});
    std.debug.print("    start <flag> ..................... start the client\n", .{});
    std.debug.print("        -fp <path> ................... specify font path (default: '')\n", .{});
    std.debug.print("        -F <factor> .................. screen size scaling factor (default: 180)\n", .{});
    std.debug.print("        --addr <address> <port> ...... TsockM server address (default: 127.0.0.1:6969)\n", .{});
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var argv = try std.process.argsWithAllocator(allocator);

    const program = argv.next().?;
    const subc = argv.next(); // subcommand

    var server_addr: []const u8 = SERVER_ADDRESS;
    var server_port: u16 = SERVER_PORT;
    var screen_scale: usize = 80;
    var font_path: []const u8 = "";

    if (subc) |subcommand| {
        if (std.mem.eql(u8, subcommand, "help")) {
            print_usage(program);
        } else if (std.mem.eql(u8, subcommand, "start")) {
            while (argv.next()) |sflag| {
                if (std.mem.eql(u8, sflag, "-F")) {
                    const opt_scale = argv.next(); 
                    if (opt_scale) |scale| {
                        screen_scale = try std.fmt.parseInt(usize, scale, 10);
                    }
                } else if (std.mem.eql(u8, sflag, "-fp")) {
                    const opt_fp = argv.next(); 
                    if (opt_fp) |fp| {
                        font_path = fp;
                    } else {
                        std.log.err("Missing path to font file!", .{});
                        print_usage(program);
                        return;
                    }
                } else if (std.mem.eql(u8, sflag, "--addr")) {
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
                    std.log.err("unknown flag `{s}`", .{sflag});
                    print_usage(program);
                }
            } 
            _ = try client.start(server_addr, server_port, screen_scale, font_path);
        } else {
            std.log.err("missing subcommand!", .{});
            print_usage(program);
        }
    } else {
        std.log.err("missing subcommand!", .{});
        print_usage(program);
    }
}
