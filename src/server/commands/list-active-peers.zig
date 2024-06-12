const std = @import("std");
const aids = @import("aids");
const core = @import("../core/core.zig");
const Command = core.Command;
const SharedData = core.SharedData;

pub fn executor(_: ?[]const u8, sd: ?*SharedData) void {
    if (sd.?.peer_pool.items.len == 0) {
        std.debug.print("Peer list: []\n", .{});
    } else {
        std.debug.print("Peer list ({d}):\n", .{sd.?.peer_pool.items.len});
        for (sd.?.peer_pool.items[0..]) |peer| {
            peer.dump();
        }
    }
}

pub const COMMAND = Command{
    .executor = executor,
};
