const std = @import("std");
const rl = @import("raylib");
const sc = @import("../screen/screen.zig");

// TODO: simple popup should store an allocator that and it should implement a deinit() that frees the text when popup expires
pub const SimplePopup = struct {
    text: []const u8 = "",
    lifetime: usize,
    SIZING: *sc.UI_SIZING,
    rec: rl.Rectangle = undefined,
    options: struct {
        default_lifetime: usize,
        font: rl.Font,
        text_color: rl.Color,
    },
    pub fn init(font: rl.Font, sizing: *sc.UI_SIZING, lifetime: usize) SimplePopup {
        return SimplePopup{
            .lifetime = lifetime,
            .SIZING = sizing,
            .options = .{
                .default_lifetime = lifetime,
                .font = font,
                .text_color = rl.Color.init(181, 181, 181, 255),
            },
        };
    }
    pub fn setTextColor(self: *@This(), color: rl.Color) void {
        self.options.text_color = color;
    }
    pub fn reset(self: *@This()) void {
        self.lifetime = self.options.default_lifetime;
    }
    pub fn update(self: *@This()) void {
        if (self.lifetime > 0) {
            self.lifetime -= 1;
        }
    }
    pub fn render(self: *@This(), previous: ?SimplePopup) !void {
        const txt = try std.fmt.allocPrintZ(std.heap.page_allocator, "{s}", .{self.text});
        const tmp_size = rl.measureTextEx(self.options.font, txt, self.SIZING.font_size, 0);
        const rw = @max(100, tmp_size.x + 40);
        const rh = @max(50, tmp_size.y + 40);
        const TPAD = 36;
        var drawRekt = rl.Rectangle{
            .x = self.SIZING.screen_width/2 - rw/2,
            .y = self.SIZING.screen_height*0.0201 + 30, // TOOD: pos.y
            .width = rw + 2*TPAD,
            .height = rh + 2*TPAD,
        };
        // TODO: animate downfall
        if (previous) |prev| {
            drawRekt.y += (prev.rec.height+50);
        }
        self.rec = drawRekt;
        rl.drawRectangleRec(drawRekt, rl.Color.init(41, 41, 41, 255));
        rl.drawRectangleLinesEx(drawRekt, std.math.clamp(self.SIZING.screen_height*0.02, 10, 15), rl.Color.init(31, 31, 31, 255));
        const txt_size = rl.measureTextEx(self.options.font, txt, self.SIZING.font_size, 0);
        const txt_pos = rl.Vector2{
            .x = drawRekt.x + drawRekt.width/2 - txt_size.x/2,
            .y = drawRekt.y + drawRekt.height/2 - txt_size.y/2 ,
        };
        rl.drawTextEx(self.options.font, txt, txt_pos, self.SIZING.font_size, 0, self.options.text_color);
    }
};
