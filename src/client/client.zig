const std = @import("std");
const aids = @import("aids");
const core = @import("./core/core.zig");
const ClientCommand = @import("./commands/commands.zig");
const ClientAction = @import("./actions/actions.zig");
const Client =  core.Client;
const Protocol = aids.Protocol;
const Logging = aids.Logging;
const cmn = aids.cmn;
const tclr = aids.TextColor;
const ui = @import("./ui/ui.zig");
const rl = @import("raylib");
const mem = std.mem;
const net = std.net;
const print = std.debug.print;

const str_allocator = std.heap.page_allocator;

fn isKeyPressed() bool {
    var keyPressed: bool = false;
    const key = rl.getKeyPressed();

    if ((@intFromEnum(key) >= 32) and (@intFromEnum(key) <= 126)) keyPressed = true;

    return keyPressed;
}

fn loadExternalFont(font_name: [:0]const u8) rl.Font {
    var tmp = [128]i32{0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127 };
    const font = rl.loadFontEx(font_name, 60, &tmp);
return font;
}

/// I am thread
fn accept_connections(sd: *core.SharedData) !void {
    while (!sd.should_exit) {
        const resp = try Protocol.collect(str_allocator, sd.client.stream);
        const opt_action = sd.client.Actioner.get(aids.Stab.parseAct(resp.action));
        if (opt_action) |act| {
            resp.dump(sd.client.log_level);
            switch (resp.type) {
                // TODO: better handling of optional types
                .REQ => act.collect.?.request(null, sd, resp),
                .RES => act.collect.?.response(sd, resp),
                .ERR => act.collect.?.err(),
                else => {
                    std.log.err("`therad::listener`: unknown protocol type!", .{});
                    unreachable;
                }
            }
        }
    }
    print("Ending `accepting_connection`\n", .{});
}

fn establishConnection(sd: *core.SharedData, thread_pool: *[1]std.Thread, username: []const u8, hostname: []const u8, port: u16) !void {
    sd.client.setUsername(username);
    sd.client.connect(str_allocator, hostname, port);
    sd.setConnected(true);
    thread_pool[0] = try std.Thread.spawn(.{}, accept_connections, .{ sd });
}

pub fn start(server_addr: []const u8, server_port: u16, screen_scale: usize, font_path: []const u8, log_level: Logging.Level) !void {
    const SW = @as(i32, @intCast(16*screen_scale));
    const SH = @as(i32, @intCast(9*screen_scale));
    rl.initWindow(SW, SH, "TsockM");
    defer rl.closeWindow();

    rl.setWindowState(.{
        .window_resizable = true
    });

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_allocator = gpa.allocator();

    var client = core.Client.init(gpa_allocator, log_level);
    defer client.deinit();

    client.Commander.add(":exit", ClientCommand.EXIT_CLIENT);
    client.Commander.add(":ping", ClientCommand.PING_CLIENT);

    client.Actioner.add(aids.Stab.Act.COMM_END, ClientAction.COMM_END);
    client.Actioner.add(aids.Stab.Act.MSG, ClientAction.MSG);
    client.Actioner.add(aids.Stab.Act.NTFY_KILL, ClientAction.NTFY_KILL);
    client.Actioner.add(aids.Stab.Act.NONE, ClientAction.BAD_REQUEST);

    // Loading font
    const self_path = try std.fs.selfExePathAlloc(gpa_allocator);
    defer gpa_allocator.free(self_path);
    const opt_self_dirname = std.fs.path.dirname(self_path);

    var font: rl.Font = undefined;
    if (font_path.len > 0) {
        const font_pathZ = try std.fmt.allocPrintZ(str_allocator, "{s}", .{font_path}); 
        font = loadExternalFont(font_pathZ);
    } else if (opt_self_dirname) |exe_dir| {
        const font_pathZ = try std.fmt.allocPrintZ(str_allocator, "{s}/{s}", .{exe_dir, "fonts/IosevkaTermSS02-SemiBold.ttf"}); 
        font = loadExternalFont(font_pathZ);
    }

    const FPS = 30;
    rl.setTargetFPS(FPS);

    var response_counter: usize = FPS*1;
    var frame_counter: usize = 0;
    // ui elements
    var message_box     = ui.InputBox{};
    var user_login_box  = ui.InputBox{};
    var user_login_btn  = ui.Button{ .text="Enter", .color = rl.Color.light_gray };
    var message_display = ui.Display{};
    // I think detaching and or joining threads is not needed becuse I handle ending of threads with core.SharedData.should_exit
    var thread_pool: [1]std.Thread = undefined;
    const messages = std.ArrayList(ui.Display.Message).init(gpa_allocator);
    var sd = core.SharedData{
        .m = std.Thread.Mutex{},
        .should_exit = false,
        .messages = messages,
        .client = client,
        .connected = false,
    };
    // Render loop
    while (!rl.windowShouldClose() and !sd.should_exit) {
        const sw = @as(f32, @floatFromInt(rl.getScreenWidth()));
        const sh = @as(f32, @floatFromInt(rl.getScreenHeight()));
        const window_extended = sh > @as(f32, @floatFromInt(SH));
        const window_extended_vert = sh > sw;
        const font_size = if (window_extended_vert) sw * 0.03 else sh * 0.05;

        rl.beginDrawing();
        defer rl.endDrawing();

        frame_counter += 1;

        // Enable writing to the input box
        if (sd.connected) {
            _ = message_box.setRec(20, sh - 100 - font_size/2, sw - 40, 50 + font_size/2); 
            _ = message_display.setRec(20, 200, sw - 40, sh - 400); 
            if (message_box.isClicked()) {
                message_box.setEnabled(true);
            } else {
                if (rl.isMouseButtonPressed(.mouse_button_left)) {
                    message_box.setEnabled(false);
                }
            }
        } else {
            // login screen
            _ = user_login_box.setRec(sw/2 - sw/4, 200 + font_size/2, sw/2, 50 + font_size/2); 
            user_login_btn.setRec(user_login_box.rec.x + sw/5.5, user_login_box.rec.y+140, sw/8, 90);
            if (user_login_box.isClicked()) {
                user_login_box.setEnabled(true);
            } else {
                if (rl.isMouseButtonPressed(.mouse_button_left)) {
                    user_login_box.setEnabled(false);
                }
            }
            if (user_login_btn.isMouseOver()) {
                user_login_btn.color = rl.Color.dark_gray;
                if (user_login_btn.isClicked()) {
                    const username = mem.sliceTo(&user_login_box.value, 0);
                    try establishConnection(&sd, &thread_pool, username, server_addr, server_port);
                    message_box.setEnabled(true);
                    user_login_box.setEnabled(false);
                }
            } else {
                user_login_btn.color = rl.Color.light_gray;
            }
        }
        var key = rl.getCharPressed();
        while (key > 0) {
            if ((key >= 32) and (key <= 125)) {
                const s = @as(u8, @intCast(key));
                if (user_login_box.enabled) {
                    user_login_box.push(s);
                } 
                if (message_box.enabled) {
                    message_box.push(s);
                }
            }

            key = rl.getCharPressed();
        }
        if (user_login_box.enabled) {
            // remove char from input box
            if (user_login_box.isKeyPressed(.key_backspace)) {
                _ = user_login_box.pop();
            }
            if (user_login_box.isKeyPressed(.key_enter)) {
                const username = mem.sliceTo(&user_login_box.value, 0);
                try establishConnection(&sd, &thread_pool, username, server_addr, server_port);
                message_box.setEnabled(true);
                user_login_box.setEnabled(false);
            }
        }
        if (message_box.enabled) {
            // remove char from input box
            if (message_box.isKeyPressed(.key_backspace)) {
                _ = message_box.pop();
            } 
            // Handle message_box input ~ client command handling
            if (message_box.isKeyPressed(.key_enter)) {
                // handle client actions
                const mcln = message_box.getCleanValue();
                if (mcln.len > 0) {
                    var splits = mem.splitScalar(u8, mcln, ' ');
                    if (splits.next()) |frst| {
                        if (client.Commander.get(frst)) |action| {
                            action.executor(frst, core.CommandData{
                                .sd = &sd,
                                .body = splits.rest(),
                            });
                        } else {
                            const msg = message_box.getCleanValue();
                            ClientAction.MSG.transmit.?.request(Protocol.TransmitionMode.UNICAST, &sd, msg);
                            _ = message_box.clean();
                        }
                    }
                }
            }
        }
        // Rendering begins here
        rl.clearBackground(rl.Color.init(18, 18, 18, 255));
        if (sd.connected) {
            // Messaging screen
            // Draw successful connection
            var buf: [256]u8 = undefined;
            const succ_str = try std.fmt.bufPrintZ(&buf,
                "Client connected successfully to `{s}:{d}` :)\n",
                .{server_addr, server_port}
            );
            if (response_counter > 0) {
                const sslen = rl.measureTextEx(font, succ_str, font_size, 0).x;
                rl.drawTextEx(font, succ_str, rl.Vector2{.x=sw/2 - sslen/2, .y=sh/2 - sh/4}, font_size, 0, rl.Color.green);
                response_counter -= 1;
            } else {
                // Draw client information
                const client_stats = sd.client.asStr(str_allocator);
                defer str_allocator.free(client_stats);
                const client_str  = try std.fmt.bufPrintZ(&buf, "{s}\n", .{client_stats});
                try message_display.render(sd.messages, str_allocator, font, font_size, frame_counter);
                rl.drawTextEx(font, client_str, rl.Vector2{.x=40, .y=20}, font_size/2, 0, rl.Color.light_gray);
                try message_box.render(window_extended, font, font_size, frame_counter);
            }
        } else {
            // Login screen
            var buf: [256]u8 = undefined;
            const title_str = try std.fmt.bufPrintZ(&buf, "TsockM", .{});
            rl.drawTextEx(
                font,
                title_str,
                rl.Vector2{.x=20, .y=25},
                font_size * 1.75,
                0,
                rl.Color.light_gray
            );
            const succ_str = try std.fmt.bufPrintZ(&buf, "Enter your username:", .{});
            rl.drawTextEx(
                font,
                succ_str,
                rl.Vector2{.x=user_login_box.rec.x, .y=user_login_box.rec.y - user_login_box.rec.height},
                font_size,
                0,
                rl.Color.light_gray
            );
            try user_login_box.render(window_extended, font, font_size, frame_counter);
            try user_login_btn.render(font, font_size);
        }
    }
    print("Ending the client\n", .{});
}
