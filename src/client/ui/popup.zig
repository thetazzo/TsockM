const rl = @import("raylib");
const rg = @import("raygui");

pub const Popup = struct {
    rec: rl.Rectangle,
    lifespan: usize,
    text: [:0]const u8 = undefined,
    font: rl.Font = undefined,
    font_size: f32 = 0,
    opts: struct {
        endless: bool
    } = .{
        .endless = false,
    },

    pub fn getTxtSize(self: *@This()) rl.Vector2 {
        return rl.measureTextEx(self.font, self.text, self.font_size, 0);
    }

    pub fn setText(self: *@This(), txt: [:0]const u8) void {
        self.text = txt;
    }

    pub fn setFont(self: *@This(), font: rl.Font, font_size: f32) void {
        self.font = font;
        self.font_size = font_size;
    }

    pub fn render(self: *@This()) void {
        const txt_size = self.getTxtSize();
        var exitcode: i32 = 0;
        while(exitcode == 0 and (self.opts.endless or self.lifespan > 0)) {
            rl.beginDrawing();
                rg.guiSetStyle(@intFromEnum(rg.GuiControl.default), @intFromEnum(rg.GuiControlProperty.border_width), 1);
                rg.guiSetStyle(@intFromEnum(rg.GuiControl.default), @intFromEnum(rg.GuiDefaultProperty.background_color), rl.colorToInt(rl.Color.init(18, 18, 18, 255)));
                exitcode = rg.guiWindowBox(self.rec, "popup");
                const txt_pos = rl.Vector2{
                    .x = self.rec.x + self.rec.width/2  - txt_size.x/2,
                    .y = self.rec.y + self.rec.height/2 - txt_size.y/2,
                };
                rl.drawTextEx(self.font, self.text, txt_pos, self.font_size, 0, rl.Color.white);
                rg.guiSetFont(self.font);
            rl.endDrawing();
            if (rl.getKeyPressed() != .key_null) {
                exitcode = 1;
            }
            if (!self.opts.endless) {
                self.lifespan -= 1;
            }
        }
    }
};
