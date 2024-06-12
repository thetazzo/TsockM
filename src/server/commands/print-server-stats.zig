const std = @import("std");
const aids = @import("aids");
const core = @import("../core/core.zig");
const Command = core.Command;
const SharedData = core.SharedData;

pub fn executor(_: ?[]const u8, sd: ?*SharedData) void {
    const now = std.time.Instant.now() catch |err| {
        std.log.err("`printServerStats`: {any}", .{err});
        std.posix.exit(1);
    };
    const dt = now.since(sd.?.server.start_time) / std.time.ns_per_ms / 1000;
    std.debug.print("==================================================\n", .{});
    std.debug.print("Server status\n", .{});
    std.debug.print("--------------------------------------------------\n", .{});
    std.debug.print("version: {s}\n", .{sd.?.server.__version__});
    std.debug.print("peers connected: {d}\n", .{sd.?.peer_pool.items.len});
    std.debug.print("uptime: {d:.3}s\n", .{dt});
    std.debug.print("address: {s}\n", .{ sd.?.server.address_str });
    std.debug.print("log_level: {s}\n", .{ @tagName(sd.?.server.log_level) });
    std.debug.print("==================================================\n", .{});
}

pub const COMMAND = Command{
    .executor = executor,
};
