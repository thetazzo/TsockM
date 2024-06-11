const std = @import("std");
const aids = @import("aids");
const core = @import("../core/core.zig");
const cmn = aids.cmn;
const Protocol = aids.Protocol;
const net = std.net;
const Command = core.Command;
const SharedData = core.SharedData;
const Peer = core.Peer;

pub fn executor(cmd: []const u8, sd: *SharedData) void {
    _ = cmd;
    const now = std.time.Instant.now() catch |err| {
        std.log.err("`printServerStats`: {any}", .{err});
        std.posix.exit(1);
    };
    const dt = now.since(sd.server.start_time) / std.time.ns_per_ms / 1000;
    std.debug.print("==================================================\n", .{});
    std.debug.print("Server status\n", .{});
    std.debug.print("--------------------------------------------------\n", .{});
    std.debug.print("peers connected: {d}\n", .{sd.peer_pool.items.len});
    std.debug.print("uptime: {d:.3}s\n", .{dt});
    std.debug.print("address: {s}\n", .{ sd.server.address_str });
    std.debug.print("==================================================\n", .{});
}

pub const COMMAND = Command{
    .executor = executor,
};
