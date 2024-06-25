const std = @import("std");
const rl = @import("raylib");
const aids = @import("aids");
const core = @import("../core/core.zig");
const ui = @import("../ui/ui.zig");

pub fn executor(_: ?[]const u8, cd: ?core.CommandData) void {
    const client = cd.?.sd.client;
    const txt = client.asStr(std.heap.page_allocator);
    var stats_popup = ui.SimplePopup.init(client.font, .TOP_CENTER, 30 * 4); // TODO: cd.sd.client.FPS
    stats_popup.text = txt;
    _ = cd.?.sd.popups.append(stats_popup) catch |err| {
        std.log.err("client-stats::executor::append: {any}", .{err});
        std.posix.exit(1);
    };
}

pub const COMMAND = aids.Stab.Command(core.CommandData){
    .executor = executor,
};
