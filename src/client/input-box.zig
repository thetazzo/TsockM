const std = @import("std");
const rl = @import("raylib");

pub const InputBox = struct {
    rec: rl.Rectangle = undefined,
    enabled: bool = false,
    value: [256]u8 = undefined,
    letter_count: usize = 0,
    pub fn setRec(self: *@This(), x: f32, y: f32, w: f32, h: f32) rl.Rectangle {
        self.rec = rl.Rectangle.init(x, y, w, h);
        return self.rec;
    }
    pub fn setEnabled(self: *@This(), val: bool) bool {
        self.enabled = val;
        return self.enabled;
    }
    pub fn isClicked(self: @This()) bool {
        if (rl.checkCollisionPointRec(rl.getMousePosition(), self.rec)) {
            if (rl.isMouseButtonPressed(.mouse_button_left)) {
                return true;
            }
        }
        return false;
    }
    pub fn clean(self: *@This()) [256]u8 {
        for (0..255) |i| {
            self.value[i] = 170;
        }
        self.letter_count = 0;
        return self.value;
    }
    pub fn render(self: @This(), window_extended: bool, font: rl.Font, font_size: f32, frame_counter: usize) !void {
        rl.drawRectangleRounded(self.rec, 0.35, 0, rl.Color.light_gray);
        var pos = rl.Vector2{
            .x = self.rec.x + 18,
            .y = self.rec.y + self.rec.height/10,
        };
        if (!window_extended) {
            pos.y += 2;
        }
        var buf2: [512]u8 = undefined;
        const mcln = std.mem.sliceTo(&self.value, 170);
        const mssg2 = try std.fmt.bufPrintZ(&buf2, "{s}", .{mcln});
        if (self.enabled) {
            const pos2 = rl.Vector2{
                .x = pos.x + rl.measureTextEx(font, mssg2, font_size, 0).x,
                .y = pos.y,
            };
            // Draw blinking cursor
            if ((frame_counter/20) % 2 == 0) rl.drawTextEx(font, "_",  pos2, font_size, 0, rl.Color.black);
            // Draw input text
        }
        rl.drawTextEx(font, mssg2, pos, font_size, 0, rl.Color.black);
    }
};
