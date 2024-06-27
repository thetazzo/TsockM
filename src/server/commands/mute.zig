const std = @import("std");
const aids = @import("aids");
const core = @import("../core/core.zig");
const SharedData = core.SharedData;

fn printUnmuteUsage() void {
    std.debug.print("usage: :unmute <flag>\n", .{});
    std.debug.print("FLAGS:\n", .{});
    std.debug.print("    * dev|DEV|D ........ print all the things\n", .{});
    std.debug.print("    * compact|COMPACT|C .... print compact protocols\n", .{});
}

fn executorMute(_: ?[]const u8, cd: ?core.sc.CommandData) void {
    cd.?.sd.server.log_level = .SILENT;
    std.debug.print("Muted the server\n", .{});
}

fn executorUnmute(cmd: ?[]const u8, cd: ?core.sc.CommandData) void {
    var split = std.mem.splitBackwardsScalar(u8, cmd.?, ' ');
    if (split.next()) |arg| {
        if (std.mem.eql(u8, arg, cmd.?)) {
            std.log.err("missing command flag", .{});
            printUnmuteUsage();
            return;
        }
        if (std.mem.eql(u8, arg, "compact") or std.mem.eql(u8, arg, "COMPACT") or std.mem.eql(u8, arg, "C")) {
            cd.?.sd.server.log_level = .COMPACT;
        } else if (std.mem.eql(u8, arg, "dev") or std.mem.eql(u8, arg, "DEV") or std.mem.eql(u8, arg, "D")) {
            cd.?.sd.server.log_level = .DEV;
        } else {
            std.log.err("unknown option `{s}`", .{arg});
            printUnmuteUsage();
            return;
        }
    }
}

pub const COMMAND_MUTE = aids.Stab.Command(core.sc.CommandData){
    .executor = executorMute,
};

pub const COMMAND_UNMUTE = aids.Stab.Command(core.sc.CommandData){
    .executor = executorUnmute,
};
