
const std = @import("std");
const aids = @import("aids");
const core = @import("../core/core.zig");
const cmn = aids.cmn;
const Protocol = aids.Protocol;
const net = std.net;
const Command = core.Command;
const SharedData = core.SharedData;
const Peer = core.Peer;

pub fn executor(_: ?[]const u8, sd: ?*SharedData) void {
    var pp_len: usize = sd.?.peer_pool.items.len;
    while (pp_len > 0) {
        pp_len -= 1;
        const p = sd.?.peer_pool.items[pp_len];
        if (p.alive == false) {
            _ = sd.?.peerRemove(pp_len);
        }
    }
}

pub const COMMAND = Command{
    .executor = executor,
};
