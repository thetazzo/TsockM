const std = @import("std");
const aids = @import("aids");
const core = @import("../core/core.zig");
const SharedData = core.SharedData;

pub fn executor(_: ?[]const u8, cd: ?core.CommandData) void {
    if (cd.?.sd.peer_pool.items.len == 0) {
        std.debug.print("Peer list: []\n", .{});
    } else {
        std.debug.print("Peer list ({d}):\n", .{cd.?.sd.peer_pool.items.len});
        for (cd.?.sd.peer_pool.items[0..]) |peer| {
            peer.dump();
        }
    }
}

pub const COMMAND = aids.Stab.Command(core.CommandData){
    .executor = executor,
};
