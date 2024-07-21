const std = @import("std");
const aids = @import("aids");
const core = @import("../core/core.zig");
const cmn = aids.cmn;
const net = std.net;
const comm = aids.v2.comm;
const SharedData = core.SharedData;
const Peer = core.Peer;

const str_allocator = std.heap.page_allocator;

fn printCmdUsage() void {
    std.debug.print("usage: :ping <flag>\n", .{});
    std.debug.print("FLAGS:\n", .{});
    std.debug.print("    * all .......... ping all peers\n", .{});
    std.debug.print("    * <peer_id> .... id of the peer to ping\n", .{});
}

pub fn executor(cmd: ?[]const u8, cd: ?core.sc.CommandData) void {
    _ = cmd;
    _ = cd;
    @panic("Not implemented yet");
}

pub const COMMAND = aids.Stab.Command(core.sc.CommandData){
    .executor = executor,
};
