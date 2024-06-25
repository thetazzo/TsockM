const std = @import("std");
const aids = @import("aids");
const core = @import("../core/core.zig");

pub fn executor(_: ?[]const u8, cd: ?core.CommandData) void {
    cd.?.sd.closeConnection();
}

pub const COMMAND = aids.Stab.Command(core.CommandData){
    .executor = executor,
};
