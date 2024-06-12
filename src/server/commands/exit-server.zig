const std = @import("std");
const aids = @import("aids");
const core = @import("../core/core.zig");
const SharedData = core.SharedData;

pub fn executor(_: ?[]const u8, _: ?*SharedData) void {
    std.debug.print("Exiting server ...\n", .{});
    std.posix.exit(0);
}

pub const COMMAND = aids.Stab.Command(SharedData){
    .executor = executor,
};
