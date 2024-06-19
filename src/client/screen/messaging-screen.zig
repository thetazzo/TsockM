const rl = @import("raylib");
const std = @import("std");
const core = @import("../core/core.zig");
const kybrd = @import("../core/keyboard.zig");
const ClientAction = @import("../actions/actions.zig");
const Protocol = @import("aids").Protocol;
const sc = @import("screen.zig");

const MessagingUD = struct{font: rl.Font};

fn update(uie: sc.UI_ELEMENTS, uis: sc.UI_SIZING, sd: *core.SharedData, data: MessagingUD) void {
    uie.message_input.setRec(20, uis.screen_height - 100 - uis.font_size/2, uis.screen_width - 40, 50 + uis.font_size/2); 
    uie.message_display.setRec(20, 200, uis.screen_width - 40, uis.screen_height - 400); 
    uie.message_input.update();
    uie.message_input.opts.keyboard = true;
// ------------------------------------------------------------
// Handle custom input
// ------------------------------------------------------------
    if (uie.message_input.enabled) {
        // Handle uis.message_input input ~ client command handling
        if (rl.isKeyPressed(.key_enter)) {
            // handle client actions
            const mcln = uie.message_input.getCleanValue();
            if (mcln.len > 0) {
                var splits = std.mem.splitScalar(u8, mcln, ' ');
                if (splits.next()) |frst| {
                    if (sd.client.Commander.get(frst)) |action| {
                        uie.message_input.opts.keyboard = false;
                        action.executor(frst, core.CommandData{
                            .sd = sd,
                            .body = splits.rest(),
                            .sizing = uis,
                            .ui_elements = uie,
                            .font = data.font,
                        });
                    } else {
                        const msg = uie.message_input.getCleanValue();
                        ClientAction.MSG.transmit.?.request(Protocol.TransmitionMode.UNICAST, sd, msg);
                    }
                    _ = uie.message_input.clean();
                }
            }
        }
    }
}
fn render(uie: sc.UI_ELEMENTS, uis: sc.UI_SIZING, sd: *core.SharedData, font: rl.Font, frame_counter: *usize) void {
    var buf: [256]u8 = undefined;
    // Draw client information
    const str_allocator = std.heap.page_allocator;
    const cmds_str  = std.fmt.bufPrintZ(
        &buf,
        "`:info` ... print information about the client\n" ++ 
        "`:exit` ... terminate the client",
        .{}
    ) catch |err| {
        std.log.err("MessagingScreen::render: {any}", .{err});
        std.posix.exit(1);
    };
    uie.message_display.render(sd.messages, str_allocator, font, uis.font_size, frame_counter.*) catch |err| {
        std.log.err("MessagingScreen::render::message_display: {any}", .{err});
        std.posix.exit(1);
    };
    rl.drawTextEx(font, cmds_str, rl.Vector2{.x=40, .y=20}, uis.font_size/2, 0, rl.Color.light_gray);
    uie.message_input.render(uis.window_extended, font, uis.font_size, frame_counter.*) catch |err| {
        std.log.err("MessagingScreen::render::cmds_str: {any}", .{err});
        std.posix.exit(1);
    };
}

pub const MessagingScreen = sc.Screen(MessagingUD){
    .update = update,
    .render = render,
};
