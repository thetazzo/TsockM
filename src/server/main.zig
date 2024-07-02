const std = @import("std");
const aids = @import("aids");
const Logging = aids.Logging;
const server = @import("server.zig");

const SERVER_ADDRESS = "127.0.0.1"; // default address is local host
const SERVER_PORT = 6969; // default port

fn print_usage(program: []const u8) void {
    std.debug.print("{s}: <subcommand>\n", .{program});
    std.debug.print("SUBCOMMANDS:\n", .{});
    std.debug.print("    help ............................. print program usage\n", .{});
    std.debug.print("    version .......................... print program version\n", .{});
    std.debug.print("    start <flag> ..................... start the server\n", .{});
    std.debug.print("        --tester ..................... start the server in testing mode (disabled commander)\n", .{});
    std.debug.print("        --log-level <level> .......... DEV|D or SILENT|S or COMPACT|C (default: COMPACT)\n", .{});
    std.debug.print("        --addr <hostname:port> ....... specify server address (default: 127.0.0.1:6969)\n", .{});
}

pub const SERVER_VERSION = "0.4.5";

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var argv = try std.process.argsWithAllocator(allocator);

    const program = argv.next().?;
    const subc = argv.next(); // subcommand

    var server_addr: []const u8 = SERVER_ADDRESS;
    var server_port: u16 = SERVER_PORT;
    var log_level: Logging.Level = Logging.Level.COMPACT;
    var tester: bool = false;

    if (subc) |subcommand| {
        if (std.mem.eql(u8, subcommand, "help")) {
            print_usage(program);
        } else if (std.mem.eql(u8, subcommand, "version")) {
            std.debug.print("{s}\n", .{SERVER_VERSION});
        } else if (std.mem.eql(u8, subcommand, "start")) {
            while (argv.next()) |arg| {
                if (std.mem.eql(u8, arg, "--tester")) {
                    tester = true;
                    server_addr = "127.0.0.1";
                    server_port = 8888;
                    log_level = .DEV;
                } else if (std.mem.eql(u8, arg, "--addr")) {
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
                } else if (std.mem.eql(u8, arg, "--log-level")) {
                    const opt_level = argv.next();
                    if (opt_level) |level| {
                        if (std.mem.eql(u8, level, "DEV") or std.mem.eql(u8, level, "D")) {
                            log_level = Logging.Level.DEV;
                        } else if (std.mem.eql(u8, level, "SILENT") or std.mem.eql(u8, level, "S")) {
                            log_level = Logging.Level.SILENT;
                        } else if (std.mem.eql(u8, level, "COMPACT") or std.mem.eql(u8, level, "C")) {
                            log_level = Logging.Level.COMPACT;
                        } else {
                            std.log.err("Invalid logging level `{s}`", .{level});
                            print_usage(program);
                            return;
                        }
                    } else {
                        std.log.err("Missing logging level", .{});
                        print_usage(program);
                        return;
                    }
                } else {
                    std.log.err("unknown flag `{s}`", .{arg});
                    print_usage(program);
                    return;
                }
            }
            _ = try server.start(server_addr, server_port, log_level, tester);
        }
    } else {
        std.log.err("missing subcommand!", .{});
        print_usage(program);
    }
}

test {
    _ = @import("core/core.zig");
    std.testing.refAllDecls(@This());
}
