const std = @import("std");
const aids = @import("aids");
const core = @import("../core/core.zig");

pub fn executor(_: ?[]const u8, cd: ?core.sc.CommandData) void {
    aids.TextColor.clearScreen();
    cd.?.sd.server.printServerRunning();
}

pub const COMMAND = aids.Stab.Command(core.sc.CommandData){
    .executor = executor,
};
