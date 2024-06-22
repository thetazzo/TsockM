const rl = @import("raylib");
const std = @import("std");
const core = @import("../core/core.zig");
const ui = @import("../ui/ui.zig");
const kybrd = @import("../core/keyboard.zig");
const sc = @import("screen.zig");

const LoginUD = struct{server_hostname: []const u8, server_port: u16};

fn connectClientToServer(sip: []const u8, sd: *core.SharedData, username: []const u8) void {
    var invalid_sip_popup = ui.SimplePopup.init(sd.client.font, &sd.sizing, 30*2);
    if (sip.len <= 0) {
        invalid_sip_popup.setTextColor(rl.Color.red);
        invalid_sip_popup.text = "missing server IP address";
        _ = sd.popups.append(invalid_sip_popup) catch |err| {
            std.log.err("login-screen::update: {}", .{err});
            std.posix.exit(1);
        };
        return;
    }
    var sip_splits = std.mem.splitScalar(u8, sip, ':');
    const hostname = sip_splits.next().?; 
    const port = std.fmt.parseInt(u16, sip_splits.rest(), 10) catch |err| {
        invalid_sip_popup.setTextColor(rl.Color.red);
        invalid_sip_popup.text = "invalid IP port";
        std.log.err("{any}", .{err});
        _ = sd.popups.append(invalid_sip_popup) catch |errapp| {
            std.log.err("login-screen::update: {}", .{errapp});
            std.posix.exit(1);
        };
        return;
    };
    sd.establishConnection(std.heap.page_allocator, username, hostname, port);
    sd.ui.message_input.setEnabled(true);
    sd.ui.username_input.setEnabled(false);
}

fn update(sd: *core.SharedData, data: LoginUD) void {
    _ = data;
    const uis = sd.sizing;
    const uie = sd.ui;
    // login screen
    uie.username_input.setRec(
        uis.screen_width/2 - uis.screen_width/4,
        200 + uis.font_size/2,
        uis.screen_width/2,
        50 + uis.font_size/2
    ); 
    uie.server_ip_input.setRec(
        uie.username_input.rec.x, 
        uie.username_input.rec.y + uie.username_input.rec.height + 80, // TODO: LABEL must be a part of input-box
        uie.username_input.rec.width,
        uie.username_input.rec.height,
    ); 
    uie.username_input.update();
    uie.server_ip_input.update();
    uie.login_btn.update();
    // -------------------------------------------------------------------------
    // Handle custom input
    // -------------------------------------------------------------------------
    if (uie.login_btn.isClicked()) {
        const username = std.mem.sliceTo(&uie.username_input.value, 0);
        const sip = uie.server_ip_input.getCleanValue();
        connectClientToServer(sip, sd, username);
    }
    if (uie.username_input.enabled or uie.server_ip_input.enabled) {
        if (rl.isKeyPressed(.key_enter)) {
            const username = std.mem.sliceTo(&uie.username_input.value, 0);
            const sip = uie.server_ip_input.getCleanValue();
            connectClientToServer(sip, sd, username);
        }
    }
}
fn render(sd: *core.SharedData, font: rl.Font, frame_counter: *usize) void {
    const uis = sd.sizing;
    const uie = sd.ui;
    // Login screen
    const str_allocator = std.heap.page_allocator;
    const title_str = std.fmt.allocPrintZ(str_allocator, "TsockM", .{}) catch |err| {
        std.log.err("LoginScreen::render: {any}", .{err});
        std.posix.exit(1);
    };
    defer str_allocator.free(title_str);
    rl.drawTextEx(
        font,
        title_str,
        rl.Vector2{.x=20, .y=25},
        uis.font_size * 1.75,
        0,
        rl.Color.light_gray
    );
    const username_input_label = std.fmt.allocPrintZ(str_allocator, "Enter your username:", .{}) catch |err| {
        std.log.err("LoginScreen::render: {any}", .{err});
        std.posix.exit(1);
    };
    defer str_allocator.free(username_input_label);
    const ui_size = rl.measureTextEx(font, username_input_label, uis.font_size, 0);
    const server_ip_input_label = std.fmt.allocPrintZ(str_allocator, "Enter TsockM server IP:", .{}) catch |err| {
        std.log.err("LoginScreen::render: {any}", .{err});
        std.posix.exit(1);
    };
    defer str_allocator.free(server_ip_input_label);
    const sip_size = rl.measureTextEx(font, server_ip_input_label, uis.font_size, 0);
    //uie.server_ip_input.rec.y += sip_size.y + 30;   
    uie.login_btn.setRec(
        uie.server_ip_input.rec.x + uis.screen_width/5.5,
        uie.server_ip_input.rec.y+140, uis.screen_width/8, 90
    );
    rl.drawTextEx(
        font,
        username_input_label,
        rl.Vector2{.x=uie.username_input.rec.x, .y=uie.username_input.rec.y - ui_size.y},
        uis.font_size,
        0,
        rl.Color.light_gray
    );
    uie.username_input.render(uis.window_extended, font, uis.font_size, frame_counter.*) catch |err| {
        std.log.err("LoginScreen::render: {any}", .{err});
        std.posix.exit(1);
    };
    rl.drawTextEx(
        font,
        server_ip_input_label,
        rl.Vector2{.x=uie.server_ip_input.rec.x, .y=uie.server_ip_input.rec.y - sip_size.y},
        uis.font_size,
        0,
        rl.Color.light_gray
    );
    uie.server_ip_input.render(uis.window_extended, font, uis.font_size, frame_counter.*) catch |err| {
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
