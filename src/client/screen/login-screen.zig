const rl = @import("raylib");
const std = @import("std");
const core = @import("../core/core.zig");
const ui = @import("../ui/ui.zig");
const kybrd = @import("../core/keyboard.zig");
const sc = @import("screen.zig");

const str_allocator = std.heap.page_allocator;
const LoginUD = struct { server_hostname: []const u8, server_port: u16 };

fn connectClientToServer(sip: []const u8, sd: *core.SharedData, username: []const u8) void {
    var invalid_sip_popup = ui.SimplePopup.init(sd.client.font, .TOP_CENTER, sd.client.FPS * 2);
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
    var hostname = sip_splits.next().?;
    if (std.mem.eql(u8, hostname, "localhost")) {
        hostname = "127.0.0.1";
    }
    const port_str = sip_splits.rest();
    var port: u16 = 6969;
    if (port_str.len > 0) {
        port = std.fmt.parseInt(u16, port_str, 10) catch |err| {
            invalid_sip_popup.setTextColor(rl.Color.red);
            invalid_sip_popup.text = "invalid IP port";
            std.log.err("{any}", .{err});
            _ = sd.popups.append(invalid_sip_popup) catch |errapp| {
                std.log.err("login-screen::update: {}", .{errapp});
                std.posix.exit(1);
            };
            return;
        };
    }
    sd.establishConnection(std.heap.page_allocator, username, hostname, port);
    sd.ui.message_input.setEnabled(true);
    sd.ui.username_input.setEnabled(false);
}

fn update(sd: *core.SharedData, data: LoginUD) void {
    _ = data;
    const uis = sd.sizing;
    const uie = sd.ui;
    uie.login_btn.updateFont(sd.client.font, sd.client.font_size);
    // login screen
    uie.username_input.setRec(
        uis.screen_width / 2 - uis.screen_width / 4,
        200 + uis.font_size / 2,
        uis.screen_width / 2,
        50 + uis.font_size / 2,
    );
    uie.server_ip_input.setRec(
        uie.username_input.rec.x,
        uie.username_input.rec.y + uie.username_input.rec.height + uie.server_ip_input.label_size.y + uis.screen_height * 0.04,
        uie.username_input.rec.width,
        uie.username_input.rec.height,
    );
    uie.login_btn.setRec(
        uie.server_ip_input.rec.x + uis.screen_width / 5.5,
        uie.server_ip_input.rec.y + 140,
        uis.screen_width / 8,
        90,
    );
    uie.username_input.update(sd);
    uie.server_ip_input.update(sd);
    uie.login_btn.update();
    // -------------------------------------------------------------------------
    // Handle custom input
    // -------------------------------------------------------------------------
    // flip flip siwitch between two inputs using the tab key
    if (rl.isKeyPressed(.key_tab)) {
        if (uie.username_input.enabled) {
            uie.username_input.setEnabled(false);
            uie.server_ip_input.setEnabled(true);
        } else if (uie.server_ip_input.enabled) {
            uie.username_input.setEnabled(true);
            uie.server_ip_input.setEnabled(false);
        } else {
            uie.username_input.setEnabled(true);
        }
    }
    if (uie.login_btn.isClicked()) {
        const username = uie.username_input.value.getValue();
        const sip = uie.server_ip_input.value.getValueZ(str_allocator);
        defer str_allocator.free(sip);
        connectClientToServer(sip, sd, username);
    }
    if (uie.username_input.enabled or uie.server_ip_input.enabled) {
        if (rl.isKeyPressed(.key_enter)) {
            const username = uie.username_input.value.getValue();
            const sip = uie.server_ip_input.value.getValueZ(str_allocator);
            defer str_allocator.free(sip);
            connectClientToServer(sip, sd, username);
        }
    }
}
fn render(sd: *core.SharedData, font: rl.Font, frame_counter: *usize) void {
    const uis = sd.sizing;
    const uie = sd.ui;
    // Login screen
    const title_str = std.fmt.allocPrintZ(str_allocator, "TsockM", .{}) catch |err| {
        std.log.err("LoginScreen::render: {any}", .{err});
        std.posix.exit(1);
    };
    defer str_allocator.free(title_str);
    rl.drawTextEx(font, title_str, rl.Vector2{ .x = 20, .y = 25 }, uis.font_size * 1.75, 0, rl.Color.light_gray);
    uie.username_input.render(&sd.sizing, frame_counter.*) catch |err| {
        std.log.err("LoginScreen::render: {any}", .{err});
        std.posix.exit(1);
    };
    uie.server_ip_input.render(&sd.sizing, frame_counter.*) catch |err| {
        std.log.err("LoginScreen::render: {any}", .{err});
        std.posix.exit(1);
    };
    uie.login_btn.render() catch |err| {
        std.log.err("LoginScreen::render: {any}", .{err});
        std.posix.exit(1);
    };
}

pub const LoginScreen = sc.Screen(LoginUD){
    .update = update,
    .render = render,
};
