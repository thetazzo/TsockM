const std = @import("std");
const rl = @import("raylib");
const kybrd = @import("../core/keyboard.zig");
const ui = @import("../ui/ui.zig");

rec: rl.Rectangle = undefined,
label_size: rl.Vector2 = undefined,
enabled: bool = false,
value: [256]u8 = undefined,
letter_count: usize = 0,
selection_mode: bool = false,
selected_text: []u8 = "",
opts: struct {
    mouse: bool,                      // default mouse support
    keyboard: bool,                   // keyboard support 
    clipboard: bool,                  // clipboard support        
    backspace_removal: bool,          // backspace removal support
    bg_color: rl.Color,               // background color         
    placeholder: [:0]const u8,        // placeholder text (visbile when defined and string length is > 0)
    label: [:0]const u8,              // input box label (visible when defined and string lenght is > 0)
} = .{
    .mouse = true,                    
    .keyboard = true,                 
    .clipboard = true,                
    .backspace_removal = true,        
    .bg_color = rl.Color.light_gray,   
    .placeholder = undefined,                 
    .label = undefined,
},

// reanme getMessageSlice
pub fn getCleanValue(self: *@This()) []u8 {
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
// Handle user keyboard input
fn consumeKeyboard(self: *@This()) void {
    if (self.enabled) {
        var key32 = rl.getCharPressed();
        while (key32 > 0) {
            if ((key32 >= 32) and (key32 <= 125)) {
                const key8 = @as(u8, @intCast(key32));
                if (self.selection_mode) {
                    if (key8 == 'x') {
                        for (0..self.selected_text.len) |i| {
                            if (self.letter_count > 0) {
                                self.letter_count -= 1;
                            }
                            self.value[i] = 0;
                        }
                        self.selected_text = "";
                        self.selection_mode = false;
                    } else if (key8 == ' ') {
                        self.selected_text = "";
                        self.selection_mode = false;
                    } else {
                        for (0..self.selected_text.len) |i| {
                            if (self.letter_count > 0) {
                                self.letter_count -= 1;
                            }
                            self.value[i] = 0;
                        }
                        self.selected_text = "";
                        self.selection_mode = false;
                        self.push(key8);
                    }
                } else {
                    self.push(key8);
                }
            }
            key32 = rl.getCharPressed();
        }
        if (self.opts.clipboard) {
            self.serveClipboardPaste();
        }
        if (self.opts.backspace_removal) {
            self.backspaceRemoval();
        }
        if (kybrd.isValidControl() and rl.isKeyPressed(.key_c)) {
            // TODO: INSERT mode like in vim (if selection mode and pressed `i` enter insert mode)
            if (self.selection_mode) {
                self.selected_text = "";
                self.selection_mode = false;
            } else {
                self.selection_mode = true;
                // TODO: popup notification of the current mode
            }
        }
        if (kybrd.isValidControl() and rl.isKeyPressed(.key_a)) {
            if (self.selection_mode) {
                const value = self.getCleanValue();
                if (value.len > 0) {
                    self.selected_text = value; 
                }
            }
        }
    }
}
// Handle of clipboard paste
fn serveClipboardPaste(self: *@This()) void {
    if (kybrd.isValidControlCombination()) {
        if (rl.isKeyPressed(.key_v)) {
            self.pushSlice(rl.getClipboardText());
        }
    }
}
// handle backspace removal
fn backspaceRemoval(self: *@This()) void {
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
    if (self.selection_mode) {
        if (self.selected_text.len <= 0) {
            // TODO: move selection cursor backwards
            return 0;
        }
    }
    if (self.letter_count > 0) {
        self.letter_count -= 1;
    }
    const chr = self.value[self.letter_count];
    self.value[self.letter_count] = 0; 
    if (self.selection_mode) {
        if (self.selected_text.len > 0) {
            self.selected_text[self.letter_count] = 0;
            self.selected_text.len = self.selected_text.len - 1;
        }
    }
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
    var buf2: [512]u8 = undefined;
    const mcln = std.mem.sliceTo(std.mem.sliceTo(&self.value, 170), 0);
    const mssg2 = try std.fmt.bufPrintZ(&buf2, "{s}", .{mcln});
    const txt_size = rl.measureTextEx(font, mssg2, font_size, 0);
    const txt_height = txt_size.y;
    const txt_hpad = 18;
    const txt_vpad = font_size * 0.1;
    const txt_pos = rl.Vector2{
        .x = self.rec.x + txt_hpad,
        .y = self.rec.y + self.rec.height/2 - txt_height/2 + txt_vpad,
    };
    self.rec.width = self.rec.width + 2*txt_hpad;
    self.rec.height = self.rec.height + 2*txt_vpad;
    rl.drawRectangleRounded(self.rec, 0.0, 0, self.opts.bg_color);
    if (!window_extended) {
        self.rec.y += 2;
    }
    if (self.enabled) {
        const cur_pos = rl.Vector2{
            .x = txt_pos.x + rl.measureTextEx(font, mssg2, font_size, 0).x,
            .y = txt_pos.y,
        };
        // Draw blinking cursor
        if (!self.selection_mode) { 
            if ((frame_counter/8) % 2 == 0) rl.drawTextEx(font, "_",  cur_pos, font_size, 0, rl.Color.black);
        } else {
            const char_width:f32 = txt_size.x / @as(f32, @floatFromInt(mssg2.len));
            rl.drawRectangleRec(rl.Rectangle.init(cur_pos.x, cur_pos.y, char_width, txt_size.y), rl.Color.black);
        }
        
        if (self.selected_text.len > 0) {
            for (0..self.selected_text.len) |i| {
                const char_width:f32 = txt_size.x / @as(f32, @floatFromInt(mssg2.len));
                const char_pos = rl.Vector2{
                    .x = txt_pos.x + char_width*@as(f32, @floatFromInt(i)),
                    .y = txt_pos.y,
                };
                rl.drawRectangleRec(rl.Rectangle.init(char_pos.x, char_pos.y, char_width, txt_size.y), rl.Color.init(12, 26, 255, 120));
            }
        }
    }
    if (self.opts.label.len > 0) {
        self.label_size = rl.measureTextEx(font, self.opts.label, font_size, 0);
        const label_pos = rl.Vector2{
            .x = self.rec.x,
            .y = self.rec.y - self.label_size.y,
        };
        rl.drawTextEx(font, self.opts.label, label_pos, font_size, 0, rl.Color.ray_white);
    }
    if (mcln.len <= 0) {
        if (self.opts.placeholder.len > 0) {
            if (self.isMouseOver() and !self.enabled) {
                rl.drawTextEx(font, self.opts.placeholder, txt_pos, font_size, 0, rl.Color.light_gray);
            } else {
                rl.drawTextEx(font, self.opts.placeholder, txt_pos, font_size, 0, rl.Color.gray);
            }
        }
    } else {
        // Draw input text
        rl.drawTextEx(font, mssg2, txt_pos, font_size, 0, rl.Color.black);
    }
}
