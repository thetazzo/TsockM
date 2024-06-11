const std = @import("std");
const aids = @import("aids");
const core = @import("../core/core.zig");
const cmn = aids.cmn;
const Protocol = aids.Protocol;
const net = std.net;
const Command = core.Command;
const SharedData = core.SharedData;
const Peer = core.Peer;

pub fn executor(cmd: []const u8, sd: *SharedData) void {
        _ = cmd;
        const stdout = std.io.getStdOut().writer();
        stdout.print("\x1B[2J\x1B[H", .{}) catch |err| {
            std.debug.print("`clearScreen`: {any}\n", .{err});
        };
        std.debug.print("Server running on `" ++ aids.TextColor.paint_green("{s}") ++ "`\n", .{sd.server.address_str});
}

pub const COMMAND = Command{
    .executor = executor,
};
