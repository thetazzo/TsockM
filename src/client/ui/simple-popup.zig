const std = @import("std");
const rl = @import("raylib");
const sc = @import("../screen/screen.zig");

const Position = enum {
    TOP_CENTER,
    BOTTOM_FIX,
};

pub const SimplePopup = struct {
    text: []const u8 = "",
    lifetime: usize,
    pos: Position,
    render_rec: rl.Rectangle = undefined,
    options: struct {
        default_lifetime: usize,
        font: rl.Font,
        text_color: rl.Color,
    },
    pub fn init(font: rl.Font, pos: Position, lifetime: usize) SimplePopup {
        return SimplePopup{
            .lifetime = lifetime,
            .pos = pos,
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
    pub fn render(self: *@This(), sizing: *sc.UI_SIZING, previous: ?*SimplePopup) !void {
        if (self.text.len <= 0) {
            std.log.err("SimplePopup: empty popup text is not allowed", .{});
            unreachable;
        }
        const txt = try std.fmt.allocPrintZ(std.heap.page_allocator, "{s}", .{self.text});
        const tmp_size = rl.measureTextEx(self.options.font, txt, sizing.font_size, 0);
        const rw = @max(100, tmp_size.x + 40);
        const rh = @max(50, tmp_size.y + 40);
        const TPAD = 36;
        switch (self.pos) {
            .TOP_CENTER => {
                self.render_rec = rl.Rectangle{
                    .x = sizing.screen_width / 2 - rw / 2,
                    .y = sizing.screen_height * 0.0201 + 30, // TOOD: pos.y
                    .width = rw + 2 * TPAD,
                    .height = rh + 2 * TPAD,
                };
                if (previous != null) {
                    if (previous.?.pos == .TOP_CENTER) {
                        self.render_rec.y += previous.?.render_rec.y + previous.?.render_rec.height;
                    }
                }
            },
            .BOTTOM_FIX => {
                self.render_rec = rl.Rectangle{
                    .x = sizing.screen_width / 2 - rw / 2 - TPAD,
                    .y = sizing.screen_height - rh * 2,
                    .width = rw + 2 * TPAD,
                    .height = rh + 2 * TPAD,
                };
            },
        }
        rl.drawRectangleRec(self.render_rec, rl.Color.init(41, 41, 41, 255));
        rl.drawRectangleLinesEx(self.render_rec, std.math.clamp(sizing.screen_height * 0.02, 10, 15), rl.Color.init(31, 31, 31, 255));
        const txt_size = rl.measureTextEx(self.options.font, txt, sizing.font_size, 0);
        const txt_pos = rl.Vector2{
            .x = self.render_rec.x + self.render_rec.width / 2 - txt_size.x / 2,
            .y = self.render_rec.y + self.render_rec.height / 2 - txt_size.y / 2,
        };
        rl.drawTextEx(self.options.font, txt, txt_pos, sizing.font_size, 0, self.options.text_color);
    }
};
