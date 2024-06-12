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
    aids.TextColor.clearScreen();
    sd.?.server.printServerRunning();
}

pub const COMMAND = Command{
    .executor = executor,
};
