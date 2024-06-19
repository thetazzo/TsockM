const std = @import("std");
const rl = @import("raylib");
const aids = @import("aids");
const core = @import("../core/core.zig");
const ui = @import("../ui/ui.zig");

pub fn executor(_: ?[]const u8, cd: ?core.CommandData) void {
    const txt = cd.?.sd.client.asStr(std.heap.page_allocator);
    const txt_size = rl.measureTextEx(cd.?.font, txt, cd.?.sizing.font_size, 0);
    const TPAD = 60;

    var popup = ui.Popup{
        .rec = rl.Rectangle{.x=cd.?.sizing.screen_width / 2 - txt_size.x/2, .y=50, .width = txt_size.x + 2*TPAD, .height = txt_size.y + 2*TPAD},
        .lifespan = 30*3,
        .opts = .{ .endless = true }
    };
    popup.setFont(cd.?.font, cd.?.sizing.font_size);
    popup.setText(txt);
    popup.render();
}

pub const COMMAND = aids.Stab.Command(core.CommandData){
    .executor = executor,
};
