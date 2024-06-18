const std = @import("std");
const rl = @import("raylib");
const kybrd = @import("../core/keyboard.zig");

rec: rl.Rectangle = undefined,
enabled: bool = false,
value: [256]u8 = undefined,
letter_count: usize = 0,
opts: struct {
    mouse: bool,
    keyboard: bool,
    clipboard: bool,
    backspace_removal: bool,
    bg_color: rl.Color,
} = .{
    .mouse = true,                    // default mouse support
    .keyboard = true,                 // default keyboard support
    .clipboard = true,                // clipboard support
    .backspace_removal = true,        // backspace removal support
    .bg_color = rl.Color.light_gray,  // background color
},

// reanme getMessageSlice
pub fn getCleanValue(self: *@This()) []const u8 {
    const cln = std.mem.sliceTo(std.mem.sliceTo(&self.value, 0), 170);
    return cln;
}
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
            rl.setMouseCursor(@intFromEnum(rl.MouseCursor.mouse_cursor_pointing_hand));
            self.opts.bg_color = rl.Color.gray;
        } else {
            rl.setMouseCursor(@intFromEnum(rl.MouseCursor.mouse_cursor_default));
            self.opts.bg_color = rl.Color.light_gray;
        }
    } else {
        rl.setMouseCursor(@intFromEnum(rl.MouseCursor.mouse_cursor_default));
        self.opts.bg_color = rl.Color.light_gray;
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
// Handle user keyboard input
fn consumeKeyboard(self: *@This()) void {
    if (self.enabled) {
        var key = rl.getCharPressed();
        while (key > 0) {
            if ((key >= 32) and (key <= 125)) {
                const s = @as(u8, @intCast(key));
                self.push(s);
            }
            key = rl.getCharPressed();
        }
        if (self.opts.clipboard) {
            self.serveClipboardPaste();
        }
        if (self.opts.backspace_removal) {
            self.backspace_removal();
        }
    }
}
// Handle of clipboard paste
fn serveClipboardPaste(self: *@This()) void {
    if (kybrd.isValidConrolCombination()) {
        if (rl.isKeyPressed(.key_v)) {
            self.pushSlice(rl.getClipboardText());
        }
    }
}
// handle backspace removal
fn backspace_removal(self: *@This()) void {
    if (kybrd.isPressedAndOrHeld(.key_backspace)) {
        _ = self.pop();
    } 
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
    self.value[self.letter_count] = 170;
    return chr;
}
// Remove all characters 
pub fn clean(self: *@This()) [256]u8 {
    for (0..255) |i| {
        self.value[i] = 170;
    }
    self.letter_count = 0;
    return self.value;
}
pub fn update(self: *@This()) void {
    if (self.opts.keyboard) {
        self.consumeKeyboard();
    }
    if (self.opts.mouse) {
        self.consumeMouse();
    }
}
pub fn render(self: *@This(), window_extended: bool, font: rl.Font, font_size: f32, frame_counter: usize) !void {
    rl.drawRectangleRounded(self.rec, 0.0, 0, self.opts.bg_color);
    if (!window_extended) {
        self.rec.y += 2;
    }
    var buf2: [512]u8 = undefined;
    const mcln = std.mem.sliceTo(&self.value, 170);
    const mssg2 = try std.fmt.bufPrintZ(&buf2, "{s}", .{mcln});
    const txt_height = rl.measureTextEx(font, mssg2, font_size, 0).y;
    const txt_hpad = 18;
    const txt_pos = rl.Vector2{
        .x = self.rec.x + txt_hpad,
        .y = self.rec.y + self.rec.height/2 - txt_height/2
    };
    if (self.enabled) {
        const cur_pos = rl.Vector2{
            .x = txt_pos.x + rl.measureTextEx(font, mssg2, font_size, 0).x,
            .y = txt_pos.y,
        };
        // Draw blinking cursor
        if ((frame_counter/8) % 2 == 0) rl.drawTextEx(font, "_",  cur_pos, font_size, 0, rl.Color.black);
    }
    // Draw input text
    rl.drawTextEx(font, mssg2, txt_pos, font_size, 0, rl.Color.black);
}
