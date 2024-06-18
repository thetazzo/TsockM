const std = @import("std");
const rl = @import("raylib");
const rg = @import("raygui");
const aids = @import("aids");
const core = @import("../core/core.zig");
const SharedData = core.SharedData;

pub fn executor(_: ?[]const u8, cd: ?core.CommandData) void {
    const txt = cd.?.sd.client.asStr(std.heap.page_allocator);
    const txt_size = rl.measureTextEx(cd.?.font, txt, cd.?.sizing.font_size, 0);
    const TPAD = 60;
    const rect = rl.Rectangle{.x=cd.?.sizing.screen_width / 2 - txt_size.x/2, .y=50, .width = txt_size.x + 2*TPAD, .height = txt_size.y + 2*TPAD};
    var exitWindow: i32 = 0;
    var hold: usize = 30*2;
    while(hold > 0) {
        rl.beginDrawing();
            rg.guiSetStyle(@intFromEnum(rg.GuiControl.default), @intFromEnum(rg.GuiControlProperty.border_width), 0);
            exitWindow = rg.guiWindowBox(rect, "popup");
            rg.guiSetStyle(@intFromEnum(rg.GuiControl.default), @intFromEnum(rg.GuiDefaultProperty.background_color), rl.colorToInt(rl.Color.init(18, 18, 18, 255)));
            rg.guiSetStyle(0, @intFromEnum(rg.GuiControlProperty.base_color_normal), rl.colorToInt(rl.Color.init(18, 18, 18, 255)));
            const txt_pos = rl.Vector2{
                .x = rect.x + rect.width/2 - txt_size.x/2,
                .y = rect.y + rect.height/2 - txt_size.y/2,
            };
            rl.drawTextEx(cd.?.font, txt, txt_pos, cd.?.sizing.font_size, 0, rl.Color.white);
            rg.guiSetFont(cd.?.font);
        rl.endDrawing();
        hold -= 1;
    }
}

pub const COMMAND = aids.Stab.Command(core.CommandData){
    .executor = executor,
};
