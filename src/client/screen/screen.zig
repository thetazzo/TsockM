const rl = @import("raylib");
const core = @import("../core/core.zig");
const ui = @import("../ui/ui.zig");

pub const LOGIN_SCREEN = @import("login-screen.zig").LoginScreen;
pub const MESSAGING_SCREEN = @import("messaging-screen.zig").MessagingScreen;

pub const UI_SIZING = struct {
    screen_width: f32 = 0,
    screen_height: f32 = 0,
    window_extended: bool = false,
    font_size: f32 = 0,
    pub fn update(self: *@This(), SW: i32, SH: i32) void {
        _ = SW;
        const sw = @as(f32, @floatFromInt(rl.getScreenWidth()));
        const sh = @as(f32, @floatFromInt(rl.getScreenHeight()));
        const window_extended = sh > @as(f32, @floatFromInt(SH));
        const window_extended_vert = sh > sw;
        const font_size = if (window_extended_vert) sw * 0.03 else sh * 0.05;
        self.screen_width = sw;
        self.screen_height = sh;
        self.window_extended = window_extended;
        self.font_size = font_size;
    }
};

pub const UI_ELEMENTS = struct {
    username_input: *ui.InputBox,
    server_ip_input: *ui.InputBox,
    login_btn: *ui.Button,
    message_input: *ui.InputBox,
    message_display: *ui.Display,
};

pub fn Screen(comptime update_data_T: type) type {
    return struct {
        update: *const fn (*core.SharedData, update_data_T) void,
        render: *const fn (*core.SharedData, rl.Font, *usize) void,
    };
}
