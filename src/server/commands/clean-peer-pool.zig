const std = @import("std");
const aids = @import("aids");
const core = @import("../core/core.zig");
const Command = core.Command;
const SharedData = core.SharedData;

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
