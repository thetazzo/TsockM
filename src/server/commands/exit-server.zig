const std = @import("std");
const aids = @import("aids");
const core = @import("../core/core.zig");
const Command = core.Command;
const SharedData = core.SharedData;

pub fn executor(_: ?[]const u8, _: ?*SharedData) void {
    std.debug.print("Exiting server ...\n", .{});
    std.posix.exit(0);
}

pub const COMMAND = Command{
    .executor = executor,
};
