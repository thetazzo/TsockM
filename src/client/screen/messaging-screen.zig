const rl = @import("raylib");
const std = @import("std");
const core = @import("../core/core.zig");
const kybrd = @import("../core/keyboard.zig");
const ClientAction = @import("../actions/actions.zig");
const Protocol = @import("aids").Protocol;
const sc = @import("screen.zig");

const MessagingUD = struct{};

const str_allocator = std.heap.page_allocator;
const cmds_str  = std.fmt.comptimePrint(
    "`:close` ... disconnect from the server\n" ++ 
    "`:info` .... print information about the client\n" ++ 
    "`:ping` .... ping another client\n" ++
    "`:exit` .... terminate the client",
    .{}
) ;
fn update(sd: *core.SharedData, _: MessagingUD) void {
    const uis = sd.sizing;
    const uie = sd.ui;
    const cmds_size = rl.measureTextEx(sd.client.font, cmds_str, uis.font_size * 3/4, 0);
    uie.message_input.setRec(20, uis.screen_height - uis.screen_height*0.12, uis.screen_width - 40, uis.screen_height*0.075); 
    uie.message_display.setRec(20, cmds_size.y + 40, uis.screen_width - 40, uie.message_input.rec.y - uis.screen_height*0.02 - (cmds_size.y + 40)); 
    uie.message_input.update();
    uie.message_input.opts.keyboard = true;
// ------------------------------------------------------------
// Handle custom input
// ------------------------------------------------------------
    if (rl.isKeyPressed(.key_tab)) {
        if (!uie.message_input.enabled) {
            uie.message_input.setEnabled(true);
        }
    }
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
                            .ui_elements = uie,
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
fn render(sd: *core.SharedData, font: rl.Font, frame_counter: *usize) void {
    _ = font;
    const uis = sd.sizing;
    const uie = sd.ui;
    // Draw client information
    uie.message_display.render(sd.messages, str_allocator, sd.client.font, uis.font_size, frame_counter.*) catch |err| {
        std.log.err("MessagingScreen::render::message_display: {any}", .{err});
        std.posix.exit(1);
    };
    // TODO: cocmmand as str should be more groupped together 
    // TODO: font scale for commands font size (3/4 is current) make it a constant variable
    rl.drawTextEx(sd.client.font, cmds_str, rl.Vector2{.x=40, .y=20}, uis.font_size * 3/4, 0, rl.Color.light_gray);
    uie.message_input.render(uis.window_extended, sd.client.font, uis.font_size, frame_counter.*) catch |err| {
        std.log.err("MessagingScreen::render::cmds_str: {any}", .{err});
        std.posix.exit(1);
    };
}

pub const MessagingScreen = sc.Screen(MessagingUD){
    .update = update,
    .render = render,
};
