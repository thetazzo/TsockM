
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
    if (sd.peer_pool.items.len == 0) {
        std.debug.print("Peer list: []\n", .{});
    } else {
        std.debug.print("Peer list ({d}):\n", .{sd.peer_pool.items.len});
        for (sd.peer_pool.items[0..]) |peer| {
            peer.dump();
        }
    }
}

pub const COMMAND = Command{
    .executor = executor,
};
