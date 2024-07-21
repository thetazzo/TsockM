const std = @import("std");
const aids = @import("aids");
const core = @import("../core/core.zig");
const SharedData = core.SharedData;

/// Remove dead peers
/// Does not kill any peer
pub fn executor(_: ?[]const u8, cd: ?core.sc.CommandData) void {
    var pp_len: usize = cd.?.sd.peer_pool.peers.len;
    while (pp_len > 0) {
        pp_len -= 1;
        const opt_peer = cd.?.sd.peer_pool.peers[pp_len];
        if (opt_peer) |peer| {
            if (peer.alive == false) {
                _ = cd.?.sd.peerPoolRemove(pp_len);
            }
        }
    }
}

pub const COMMAND = aids.Stab.Command(core.sc.CommandData){
    .executor = executor,
};
