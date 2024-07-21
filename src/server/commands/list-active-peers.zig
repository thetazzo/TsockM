const std = @import("std");
const aids = @import("aids");
const core = @import("../core/core.zig");
const SharedData = core.SharedData;

pub fn executor(_: ?[]const u8, cd: ?core.sc.CommandData) void {
    if (cd.?.sd.peer_pool.peers.len == 0) {
        std.debug.print("Peer list: []\n", .{});
    } else {
        std.debug.print("Peer list ({d}):\n", .{cd.?.sd.peer_pool.peers.len});
        for (cd.?.sd.peer_pool.peers[0..]) |opt_peer| {
            if (opt_peer) |peer| {
                peer.dump();
            }
        }
    }
}

pub const COMMAND = aids.Stab.Command(core.sc.CommandData){
    .executor = executor,
};
