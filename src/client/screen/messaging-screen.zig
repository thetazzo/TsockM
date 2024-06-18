const rl = @import("raylib");
const std = @import("std");
const core = @import("../core/core.zig");
const ClientAction = @import("../actions/actions.zig");
const Protocol = @import("aids").Protocol;
const sc = @import("screen.zig");

const MessagingUD = struct{server_hostname: []const u8, server_port: u16};

fn update(uie: sc.UI_ELEMENTS, uis: sc.UI_SIZING, sd: *core.SharedData, data: MessagingUD) void {
    _ = data;
    uie.message_input.setRec(20, uis.screen_height - 100 - uis.font_size/2, uis.screen_width - 40, 50 + uis.font_size/2); 
    uie.message_display.setRec(20, 200, uis.screen_width - 40, uis.screen_height - 400); 
    if (uie.message_input.isClicked()) {
        uie.message_input.setEnabled(true);
    } else {
        if (rl.isMouseButtonPressed(.mouse_button_left)) {
            uie.message_input.setEnabled(false);
        }
    }
// ------------------------------------------------------------
// Handle input
// ------------------------------------------------------------
    if (uie.message_input.enabled) {
        var key = rl.getCharPressed();
        while (key > 0) {
            if ((key >= 32) and (key <= 125)) {
                const s = @as(u8, @intCast(key));
                uie.message_input.push(s);
            }

            key = rl.getCharPressed();
        }
        // remove char from input box
        if (uie.message_input.isKeyPressed(.key_backspace)) {
            _ = uie.message_input.pop();
        } 
        // Handle uis.message_input input ~ client command handling
        if (uie.message_input.isKeyPressed(.key_enter)) {
            // handle client actions
            const mcln = uie.message_input.getCleanValue();
            if (mcln.len > 0) {
                var splits = std.mem.splitScalar(u8, mcln, ' ');
                if (splits.next()) |frst| {
                    if (sd.client.Commander.get(frst)) |action| {
                        action.executor(frst, core.CommandData{
                            .sd = sd,
                            .body = splits.rest(),
                        });
                    } else {
                        const msg = uie.message_input.getCleanValue();
                        ClientAction.MSG.transmit.?.request(Protocol.TransmitionMode.UNICAST, sd, msg);
                        _ = uie.message_input.clean();
                    }
                }
            }
        }
    }
}
fn render(uie: sc.UI_ELEMENTS, uis: sc.UI_SIZING, sd: *core.SharedData, font: rl.Font, frame_counter: *usize) void {
    var buf: [256]u8 = undefined;
    // Draw client information
    const str_allocator = std.heap.page_allocator;
    const client_stats = sd.client.asStr(str_allocator);
    defer str_allocator.free(client_stats);
    const client_str  = std.fmt.bufPrintZ(&buf, "{s}\n", .{client_stats}) catch |err| {
        std.log.err("MessagingScreen::render: {any}", .{err});
        std.posix.exit(1);
    };
    uie.message_display.render(sd.messages, str_allocator, font, uis.font_size, frame_counter.*) catch |err| {
        std.log.err("MessagingScreen::render: {any}", .{err});
        std.posix.exit(1);
    };
    rl.drawTextEx(font, client_str, rl.Vector2{.x=40, .y=20}, uis.font_size/2, 0, rl.Color.light_gray);
    uie.message_input.render(uis.window_extended, font, uis.font_size, frame_counter.*) catch |err| {
        std.log.err("MessagingScreen::render: {any}", .{err});
        std.posix.exit(1);
    };
}

pub const MessagingScreen = sc.Screen(MessagingUD){
    .update = update,
    .render = render,
};
