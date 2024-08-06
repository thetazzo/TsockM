const std = @import("std");
const rl = @import("raylib");
const core = @import("../core/core.zig");
const kybrd = @import("../core/keyboard.zig");
const ui = @import("../ui/ui.zig");
const sc = @import("../screen/screen.zig");

const InputMode = enum {
    SELECTION,
    INSERT,
};

const DEFAULT_FONT = .{
    .family = undefined,
};

const DEFAULT_OPTS = .{
    .mouse = true,
    .keyboard = true,
    .clipboard = true,
    .backspace_removal = true,
    .bg_color = rl.Color.light_gray,
    .placeholder = undefined,
    .label = undefined,
};

const Text = struct {
    value: [256]u8 = undefined,
    letter_count: usize = 0,
    pub fn getValue(self: *@This()) []u8 {
        return std.mem.sliceTo(&self.value, 0);
    }
    // allocated value that is 0 terminated [:0]const u8
    pub fn getValueZ(self: *@This(), allocator: std.mem.Allocator) [:0]u8 {
        const cln = std.mem.sliceTo(&self.value, 0);
        const allocd = std.fmt.allocPrintZ(allocator, "{s}", .{cln}) catch |err| {
            std.log.err("input-box::getValueAllocd::allocd: {any}", .{err});
            std.posix.exit(1);
        };
        return allocd;
    }
    // push a single character
    pub fn push(self: *@This(), char: u8) void {
        self.value[self.letter_count] = char;
        self.letter_count += 1;
    }
    // push a whole string of characters
    pub fn pushSlice(self: *@This(), slice: [:0]const u8) void {
        for (0..slice.len) |i| {
            self.value[self.letter_count] = slice[i];
            self.letter_count += 1;
        }
    }
    // Remove the last character
    pub fn pop(self: *@This()) u8 {
        if (self.letter_count > 0) {
            self.letter_count -= 1;
        }
        const chr = self.value[self.letter_count];
        self.value[self.letter_count] = 0;
        return chr;
    }
    // Remove all characters
    pub fn clean(self: *@This()) [256]u8 {
        for (0..255) |i| {
            self.value[i] = 0;
        }
        self.letter_count = 0;
        return self.value;
    }
};

pub const InputBox = struct {
    rec: rl.Rectangle = undefined,
    label_size: rl.Vector2 = undefined,
    enabled: bool = false,
    value: Text = Text{},
    input_mode: InputMode = .INSERT,
    input_buf: []u8 = "",
    font: struct {
        family: rl.Font,
    } = DEFAULT_FONT,
    opts: struct {
        mouse: bool, // default mouse support
        keyboard: bool, // keyboard support
        clipboard: bool, // clipboard support
        backspace_removal: bool, // backspace removal support
        bg_color: rl.Color, // background color
        placeholder: [:0]const u8, // placeholder text (visbile when defined and string length is > 0)
        label: [:0]const u8, // input box label (visible when defined and string lenght is > 0)
    } = DEFAULT_OPTS,
    pub fn setRec(self: *@This(), x: f32, y: f32, w: f32, h: f32) void {
        self.rec = rl.Rectangle.init(x, y, w, h);
    }
    pub fn setEnabled(self: *@This(), val: bool) void {
        self.enabled = val;
    }
    pub fn isClicked(self: @This()) bool {
        if (rl.checkCollisionPointRec(rl.getMousePosition(), self.rec)) {
            if (rl.isMouseButtonPressed(.mouse_button_left)) {
                return true;
            }
        }
        return false;
    }
    // check mouse pointer and input box collision
    pub fn isMouseOver(self: @This()) bool {
        if (rl.checkCollisionPointRec(rl.getMousePosition(), self.rec)) {
            return true;
        }
        return false;
    }
    // Handle user input
    fn consumeMouse(self: *@This()) void {
        if (!self.enabled) {
            if (self.isMouseOver()) {
                self.opts.bg_color = rl.Color.gray;
                rl.setMouseCursor(@intFromEnum(rl.MouseCursor.mouse_cursor_pointing_hand));
            } else {
                self.opts.bg_color = rl.Color.light_gray;
                rl.setMouseCursor(@intFromEnum(rl.MouseCursor.mouse_cursor_default));
            }
        } else {
            self.opts.bg_color = rl.Color.light_gray;
            rl.setMouseCursor(@intFromEnum(rl.MouseCursor.mouse_cursor_default));
        }
        if (self.isClicked()) {
            self.setEnabled(true);
            return;
        } else {
            if (rl.isMouseButtonPressed(.mouse_button_left)) {
                self.setEnabled(false);
                return;
            }
        }
    }
    /// Handle user keyboard input
    fn consumeKeyboard(self: *@This(), sd: *core.SharedData) void {
        const str_allocator = std.heap.page_allocator;
        var ntfy_popup = ui.SimplePopup.init(self.font.family, .BOTTOM_FIX, sd.client.FPS * 2);
        if (self.enabled) {
            var key32 = rl.getCharPressed();
            while (key32 > 0) {
                if ((key32 >= 32) and (key32 <= 125)) {
                    const key8 = @as(u8, @intCast(key32));
                    switch (self.input_mode) {
                        .SELECTION => {
                            if (key8 == 'x' or key8 == 's') {
                                var vv = self.value.value;
                                const vvc = std.mem.sliceTo(&vv, 0);
                                var nv = std.mem.split(u8, &vv, self.input_buf);
                                _ = nv.next().?;
                                _ = self.clean();
                                const rem = nv.next().?;
                                std.mem.copyForwards(u8, &self.value.value, rem);
                                self.value.letter_count = vvc.len - (256 - rem.len);
                                self.input_buf = "";
                                self.input_mode = .INSERT;
                                ntfy_popup.text = "TEXT DELETED";
                                sd.pushPopup(ntfy_popup);
                            } else if (key8 == 'i') {
                                self.input_buf = "";
                                self.input_mode = .INSERT;
                                ntfy_popup.text = "INSERT";
                                sd.pushPopup(ntfy_popup);
                            } else if (key8 == 'y') {
                                const txt = self.value.getValueZ(str_allocator);
                                defer str_allocator.free(txt);
                                rl.setClipboardText(txt);
                                self.input_buf = "";
                                ntfy_popup.text = "Text copied";
                                ntfy_popup.setTextColor(rl.Color.green);
                                sd.pushPopup(ntfy_popup);
                            }
                        },
                        .INSERT => {
                            self.push(key8);
                        },
                    }
                }
                key32 = rl.getCharPressed();
            }
            // clipboard support
            if (self.opts.clipboard) {
                if (kybrd.isValidControlCombination()) {
                    if (rl.isKeyPressed(.key_v)) {
                        const cd = rl.getClipboardText();
                        self.pushSlice(std.mem.sliceTo(cd, 0));
                    }
                }
            }
            // backspace support
            if (self.opts.backspace_removal) {
                if (kybrd.isPressedAndOrHeld(.key_backspace)) {
                    switch (self.input_mode) {
                        .INSERT => {
                            _ = self.pop();
                        },
                        .SELECTION => {
                            if (self.input_buf.len > 0) {
                                self.input_buf[self.input_buf.len - 1] = 0;
                                self.input_buf.len = self.input_buf.len - 1;
                            }
                        },
                    }
                }
            }
            // CTRL C
            if (kybrd.isValidControl() and rl.isKeyPressed(.key_c)) {
                if (self.enabled) {
                    switch (self.input_mode) {
                        .SELECTION => {
                            self.input_buf = "";
                            self.input_mode = .INSERT;
                            ntfy_popup.text = "INSERT";
                        },
                        .INSERT => {
                            self.input_mode = .SELECTION;
                            ntfy_popup.text = "VISUAL SELECT";
                        },
                    }
                    sd.pushPopup(ntfy_popup);
                }
            }
            // SHIFT A
            if (kybrd.isValidShift() and rl.isKeyPressed(.key_a)) {
                if (self.input_mode == .SELECTION) {
                    const value = self.value.getValueZ(str_allocator);
                    if (value.len > 0) {
                        self.input_buf = value;
                    }
                }
            }
        }
    }
    /// Push a single character into input box value
    pub fn push(self: *@This(), char: u8) void {
        self.value.push(char);
    }
    /// Push a whole string of characters that are 0 terminated into input box value
    pub fn pushSlice(self: *@This(), slice: [:0]const u8) void {
        self.value.pushSlice(slice);
    }
    /// Remove the last character from input box value
    pub fn pop(self: *@This()) u8 {
        if (self.input_mode == .SELECTION) {
            if (self.input_buf.len <= 0) {
                // TODO: move selection cursor backwards
                return 0;
            } else {
                self.input_buf[self.input_buf.len - 1] = 0;
                self.input_buf.len = self.input_buf.len - 1;
            }
        }
        return self.value.pop();
    }
    /// Remove all characters from input box value
    pub fn clean(self: *@This()) [256]u8 {
        return self.value.clean();
    }
    pub fn update(self: *@This(), sd: *core.SharedData) void {
        if (self.opts.keyboard) {
            self.consumeKeyboard(sd);
        }
        if (self.opts.mouse) {
            self.consumeMouse();
        }
    }
    pub fn render(self: *@This(), sizing: *sc.UI_SIZING, frame_counter: usize) !void {
        const str_allocator = std.heap.page_allocator;
        const mssg2 = self.value.getValueZ(str_allocator);
        defer str_allocator.free(mssg2);

        const txt_size = rl.measureTextEx(self.font.family, mssg2, sizing.font_size, 0);
        const txt_height = txt_size.y;
        const txt_hpad = 18;
        const txt_vpad = sizing.font_size * 0.1;
        const txt_pos = rl.Vector2{
            .x = self.rec.x + txt_hpad,
            .y = self.rec.y + self.rec.height / 2 - txt_height / 2 + txt_vpad,
        };
        self.rec.width = self.rec.width + 2 * txt_hpad;
        self.rec.height = self.rec.height + 2 * txt_vpad;
        rl.drawRectangleRounded(self.rec, 0.0, 0, self.opts.bg_color);
        if (!sizing.window_extended) {
            self.rec.y += 2;
        }
        if (self.enabled) {
            var cur_pos = rl.Vector2{
                .x = txt_pos.x + rl.measureTextEx(self.font.family, mssg2, sizing.font_size, 0).x,
                .y = txt_pos.y,
            };
            // Draw blinking cursor
            if (self.input_mode == .INSERT) {
                if ((frame_counter / 8) % 2 == 0) rl.drawTextEx(self.font.family, "_", cur_pos, sizing.font_size, 0, rl.Color.black);
            } else if (self.input_mode == .SELECTION) {
                const char_width: f32 = txt_size.x / @as(f32, @floatFromInt(mssg2.len));
                if (self.input_buf.len > 0) {
                    cur_pos = rl.Vector2{
                        .x = txt_pos.x + char_width * @as(f32, @floatFromInt(self.input_buf.len)),
                        .y = txt_pos.y,
                    };
                }
                rl.drawRectangleRec(rl.Rectangle.init(cur_pos.x, cur_pos.y, char_width, txt_size.y), rl.Color.init(0, 0, 0, 180));
            }
            if (self.input_buf.len > 0) {
                for (0..self.input_buf.len) |i| {
                    const char_width: f32 = txt_size.x / @as(f32, @floatFromInt(mssg2.len));
                    const char_pos = rl.Vector2{
                        .x = txt_pos.x + char_width * @as(f32, @floatFromInt(i)),
                        .y = txt_pos.y,
                    };
                    rl.drawRectangleRec(rl.Rectangle.init(char_pos.x, char_pos.y, char_width, txt_size.y), rl.Color.init(12, 26, 255, 120));
                }
            }
        }
        if (self.opts.label.len > 0) {
            self.label_size = rl.measureTextEx(self.font.family, self.opts.label, sizing.font_size, 0);
            const label_pos = rl.Vector2{
                .x = self.rec.x,
                .y = self.rec.y - self.label_size.y,
            };
            rl.drawTextEx(self.font.family, self.opts.label, label_pos, sizing.font_size, 0, rl.Color.ray_white);
        }
        if (mssg2.len <= 0) {
            if (self.opts.placeholder.len > 0) {
                if (self.isMouseOver() and !self.enabled) {
                    rl.drawTextEx(self.font.family, self.opts.placeholder, txt_pos, sizing.font_size, 0, rl.Color.light_gray);
                } else {
                    rl.drawTextEx(self.font.family, self.opts.placeholder, txt_pos, sizing.font_size, 0, rl.Color.gray);
                }
            }
        } else {
            // Draw input text
            rl.drawTextEx(self.font.family, mssg2, txt_pos, sizing.font_size, 0, rl.Color.black);
        }
    }
};
