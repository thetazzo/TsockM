const rl = @import("raylib");
const std = @import("std");
const core = @import("../core/core.zig");
const kybrd = @import("../core/keyboard.zig");
const sc = @import("screen.zig");

const LoginUD = struct{server_hostname: []const u8, server_port: u16};

fn update(sd: *core.SharedData, data: LoginUD) void {
    const uis = sd.sizing;
    const uie = sd.ui;
    // login screen
    uie.username_input.setRec(
        uis.screen_width/2 - uis.screen_width/4, 200 + uis.font_size/2,
        uis.screen_width/2, 50 + uis.font_size/2
    ); 
    uie.login_btn.setRec(
        uie.username_input.rec.x + uis.screen_width/5.5,
        uie.username_input.rec.y+140, uis.screen_width/8, 90
    );
    uie.username_input.update();
    uie.login_btn.update();
// -------------------------------------------------------------------------
// Handle custom input
// -------------------------------------------------------------------------
    if (uie.login_btn.isClicked()) {
        const username = std.mem.sliceTo(&uie.username_input.value, 0);
        sd.establishConnection(username, data.server_hostname, data.server_port);
        uie.message_input.setEnabled(true);
        uie.username_input.setEnabled(false);
    }
    if (uie.username_input.enabled) {
        if (rl.isKeyPressed(.key_enter)) {
            const username = std.mem.sliceTo(&uie.username_input.value, 0);
            sd.establishConnection(username, data.server_hostname, data.server_port);
            uie.message_input.setEnabled(true);
            uie.username_input.setEnabled(false);
        }
    }
}
fn render(sd: *core.SharedData, font: rl.Font, frame_counter: *usize) void {
    const uis = sd.sizing;
    const uie = sd.ui;
    // Login screen
    var buf: [256]u8 = undefined;
    const title_str = std.fmt.bufPrintZ(&buf, "TsockM", .{}) catch |err| {
        std.log.err("LoginScreen::render: {any}", .{err});
        std.posix.exit(1);
    };
    rl.drawTextEx(
        font,
        title_str,
        rl.Vector2{.x=20, .y=25},
        uis.font_size * 1.75,
        0,
        rl.Color.light_gray
    );
    const succ_str = std.fmt.bufPrintZ(&buf, "Enter your username:", .{}) catch |err| {
        std.log.err("LoginScreen::render: {any}", .{err});
        std.posix.exit(1);
    };
    rl.drawTextEx(
        font,
        succ_str,
        rl.Vector2{.x=uie.username_input.rec.x, .y=uie.username_input.rec.y - uie.username_input.rec.height},
        uis.font_size,
        0,
        rl.Color.light_gray
    );
    uie.username_input.render(uis.window_extended, font, uis.font_size, frame_counter.*) catch |err| {
        std.log.err("LoginScreen::render: {any}", .{err});
        std.posix.exit(1);
    };
    uie.login_btn.render(font, uis.font_size) catch |err| {
        std.log.err("LoginScreen::render: {any}", .{err});
        std.posix.exit(1);
    };
}

pub const LoginScreen = sc.Screen(LoginUD){
    .update = update,
    .render = render,
};
