const std = @import("std");
const aids = @import("aids");
const core = @import("../core/core.zig");
const Command = core.Command;
const SharedData = core.SharedData;

// TODO use shared data when printing server commands ~ sd.Commander.usageList().print();
pub fn executor(_: ?[]const u8, _: ?*SharedData) void {
    std.debug.print("COMMANDS:\n", .{});
    std.debug.print("    * :c .............................. clear screen\n", .{});
    std.debug.print("    * :info ........................... print server statiistics\n", .{});
    std.debug.print("    * :mute ........................... disable logging\n", .{});
    std.debug.print("    * :exit ........................... terminate server\n", .{});
    std.debug.print("    * :help ........................... print server commands\n", .{});
    std.debug.print("    * :clean-pool ..................... removes dead peers\n", .{});
    std.debug.print("    * :list | :ls  .................... list all active peers\n", .{});
    std.debug.print("    * :ping <peer_id> | all ........... ping peer/s and update its/their life status\n", .{});
    std.debug.print("    * :kill <peer_id> | all ........... kill peer/s\n", .{});
}

pub const COMMAND = Command{
    .executor = executor,
};

