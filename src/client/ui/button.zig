const std = @import("std");
const rl = @import("raylib");

pub const Button = struct {
    rec: rl.Rectangle = undefined,
    text: []const u8,
    opts: struct {
        bg_color: rl.Color,
        mouse: bool,
    } = .{
        .bg_color = rl.Color.light_gray,
        .mouse = true // default mouse support
    },
    pub fn setText(self: *@This(), text: []const u8) void {
        self.text = text;
    }
    pub fn setRec(self: *@This(), x: f32, y: f32, w: f32, h: f32) void {
        self.rec = rl.Rectangle.init(x, y, w, h);
    }
    pub fn isMouseOver(self: @This()) bool {
        if (rl.checkCollisionPointRec(rl.getMousePosition(), self.rec)) {
            return true;
        }
        return false;
    }
    pub fn isClicked(self: @This()) bool {
        if (rl.checkCollisionPointRec(rl.getMousePosition(), self.rec)) {
            if (rl.isMouseButtonPressed(.mouse_button_left)) {
                return true;
            }
        }
        return false;
    }
    fn consumeMouse(self: *@This()) void {
        if (self.isMouseOver()) {
            self.opts.bg_color = rl.Color.dark_gray;
            rl.setMouseCursor(@intFromEnum(rl.MouseCursor.mouse_cursor_pointing_hand));
        } else {
            self.opts.bg_color = rl.Color.light_gray;
        }
    }
    pub fn update(self: *@This()) void {
        if (self.opts.mouse) {
            self.consumeMouse();
        }
    }
    pub fn render(self: @This(), font: rl.Font, font_size: f32) !void {
        rl.drawRectangle(
            @intFromFloat(self.rec.x),
            @intFromFloat(self.rec.y),
            @intFromFloat(self.rec.width),
            @intFromFloat(self.rec.height),
            self.opts.bg_color,
        );
        var buf: [256] u8 = undefined;
        const btext = try std.fmt.bufPrintZ(&buf, "{s}", .{self.text});
        const txt_width = rl.measureTextEx(font, btext, font_size, 0).x;
        const txt_height = rl.measureTextEx(font, btext, font_size, 0).y;
        rl.drawTextEx(font, btext, rl.Vector2{.x=self.rec.x+self.rec.width/2 - txt_width/2, .y=self.rec.y+self.rec.height/2 - txt_height/2}, font_size, 0, rl.Color.black);
    }
};
