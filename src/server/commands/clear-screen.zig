const std = @import("std");
const aids = @import("aids");
const core = @import("../core/core.zig");
const cmn = aids.cmn;
const Protocol = aids.proto;
const net = std.net;
const SharedData = core.SharedData;
const Peer = core.Peer;

pub fn executor(_: ?[]const u8, cd: ?core.sc.CommandData) void {
    aids.TextColor.clearScreen();
    cd.?.sd.server.printServerRunning();
}

pub const COMMAND = aids.Stab.Command(core.sc.CommandData){
    .executor = executor,
};
