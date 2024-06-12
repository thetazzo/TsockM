const std = @import("std");
const aids = @import("aids");
const core = @import("../core/core.zig");
const Action = core.Action;
const SharedData = core.SharedData;

fn internal(sd: *SharedData) void {
    var pp_len: usize = sd.peer_pool.items.len;
    while (pp_len > 0) {
        pp_len -= 1;
        const p = sd.peer_pool.items[pp_len];
        if (p.alive == false) {
            _ = sd.peerRemove(pp_len);
        }
    }
}

pub const ACTION = Action{
    .collect = null,
    .transmit = null,
    .internal = internal,
};
