const std = @import("std");
const aids = @import("aids");
const core = @import("./core/core.zig");
const ClientCommand = @import("./commands/commands.zig");
const ClientAction = @import("./actions/actions.zig");
const sc = @import("./screen/screen.zig");
const ui = @import("./ui/ui.zig");
const rl = @import("raylib");
const LoginScreen = sc.LOGIN_SCREEN;
const MessagingScreen = sc.MESSAGING_SCREEN;
const Client = core.Client;
const Protocol = aids.Protocol;
const Logging = aids.Logging;
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
    var tmp = [_]i32{0} ** 128;
    for (0..127) |i| {
        tmp[i] = @as(i32, @intCast(i));
    }
    const font = rl.loadFontEx(font_name, 60, &tmp);
    return font;
}

/// I am thread
fn acceptConnections(sd: *core.SharedData) !void {
    {
        sd.m.lock();
        defer sd.m.unlock();
        while (!sd.connected) {
            // wait for client to connect
            sd.cond.wait(&sd.m);
        }
    }
    var turnery: bool = false;
    while (!sd.should_exit) {
        while (sd.connected) {
            turnery = true;
            const resp = try Protocol.collect(str_allocator, sd.client.stream);
            const opt_action = sd.client.Actioner.get(aids.Stab.parseAct(resp.action));
            if (opt_action) |act| {
                resp.dump(sd.client.log_level);
                switch (resp.type) {
                    // TODO: better handling of optional types
                    .REQ => act.collect.?.request(null, sd, resp),
                    .RES => act.collect.?.response(sd, resp),
                    .ERR => act.collect.?.err(sd),
                    else => {
                        std.log.err("`therad::listener`: unknown protocol type!", .{});
                        unreachable;
                    },
                }
            }
        }
        if (turnery) {
            print("Ending `accepting_connection`\n", .{});
            turnery = false;
        }
    }
}

pub fn start(server_hostname: []const u8, server_port: u16, screen_scale: usize, font_path: []const u8, log_level: Logging.Level) !void {
    const SW = @as(i32, @intCast(16 * screen_scale));
    const SH = @as(i32, @intCast(9 * screen_scale));
    rl.initWindow(SW, SH, "TsockM");
    defer rl.closeWindow();

    rl.setWindowState(.{ .window_resizable = true });

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_allocator = gpa.allocator();

    // Loading font
    const self_path = try std.fs.selfExePathAlloc(gpa_allocator);
    defer gpa_allocator.free(self_path);
    const opt_self_dirname = std.fs.path.dirname(self_path);

    var font: rl.Font = undefined;
    if (font_path.len > 0) {
        const font_pathZ = try std.fmt.allocPrintZ(str_allocator, "{s}", .{font_path});
        font = loadExternalFont(font_pathZ);
    } else if (opt_self_dirname) |exe_dir| {
        const fp = "fonts/IosevkaTermSS02-SemiBold.ttf";
        const font_pathZ = try std.fmt.allocPrintZ(str_allocator, "{s}/{s}", .{ exe_dir, fp });
        font = loadExternalFont(font_pathZ);
    }

    var client = core.Client.init(gpa_allocator, font, log_level);

    client.Commander.add(":exit", ClientCommand.EXIT_CLIENT);
    client.Commander.add(":close", ClientCommand.CLOSE_CLIENT);
    client.Commander.add(":info", ClientCommand.CLIENT_STATS);
    client.Commander.add(":ping", ClientCommand.PING_CLIENT);

    client.Actioner.add(aids.Stab.Act.COMM_END, ClientAction.COMM_END);
    client.Actioner.add(aids.Stab.Act.MSG, ClientAction.MSG);
    client.Actioner.add(aids.Stab.Act.NTFY_KILL, ClientAction.NTFY_KILL);
    client.Actioner.add(aids.Stab.Act.NONE, ClientAction.BAD_REQUEST);

    const FPS = 30;
    rl.setTargetFPS(FPS);

    //var response_counter: usize = FPS*1;
    var frame_counter: usize = 0;
    // ui elements
    // I think detaching and or joining threads is not needed becuse I handle ending of threads with core.SharedData.should_exit
    var thread_pool: [1]std.Thread = undefined;
    const messages = std.ArrayList(ui.Display.Message).init(gpa_allocator);
    defer messages.deinit();
    const popups = std.ArrayList(ui.SimplePopup).init(gpa_allocator);
    defer popups.deinit();

    var username_input = ui.InputBox{ .enabled = true };
    username_input.opts.placeholder = "Username";
    username_input.opts.label = "Enter your username:";
    var server_ip_input = ui.InputBox{};
    server_ip_input.opts.placeholder = "hostname:port";
    server_ip_input.opts.label = "Enter TsockM server IP:";
    var login_btn = ui.Button{ .text = "Login" };
    var message_input = ui.InputBox{};
    message_input.opts.placeholder = "Message";
    var message_display = ui.Display{};
    var sd = core.SharedData{
        .m = std.Thread.Mutex{},
        .cond = std.Thread.Condition{},
        .should_exit = false,
        .messages = messages,
        .popups = popups,
        .client = client,
        .connected = false,
        .ui = sc.UI_ELEMENTS{
            .username_input = &username_input,
            .server_ip_input = &server_ip_input,
            .login_btn = &login_btn,
            .message_input = &message_input,
            .message_display = &message_display,
        },
    };

    thread_pool[0] = try std.Thread.spawn(.{}, acceptConnections, .{&sd});

    // Render loop
    while (!rl.windowShouldClose() and !sd.should_exit) {
        //const sw = @as(f32, @floatFromInt(rl.getScreenWidth()));
        //const sh = @as(f32, @floatFromInt(rl.getScreenHeight()));
        //const window_extended_vert = sh > sw;
        //const font_size = if (window_extended_vert) sw * 0.03 else sh * 0.05;
        sd.updateSizing(SW, SH);

        rl.beginDrawing();
        defer rl.endDrawing();

        frame_counter += 1;

        // Enable writing to the input box
        if (sd.connected) {
            MessagingScreen.update(&sd, .{});
        } else {
            LoginScreen.update(&sd, .{ .server_hostname = server_hostname, .server_port = server_port });
        }
        // Rendering begins here
        rl.clearBackground(rl.Color.init(18, 18, 18, 255));
        if (sd.connected) {
            // Messaging screen
            // Draw successful connection

            MessagingScreen.render(&sd, font, &frame_counter);
            //if (response_counter > 0) {
            //    const sslen = rl.measureTextEx(font, succ_str, font_size, 0).x;
            //    rl.drawTextEx(font, succ_str, rl.Vector2{.x=sw/2 - sslen/2, .y=sh/2 - sh/4}, font_size, 0, rl.Color.green);
            //    response_counter -= 1;
            //} else {
            //}
        } else {
            LoginScreen.render(&sd, font, &frame_counter);
        }

        var i = sd.popups.items.len;
        while (i > 0) {
            var popup = &sd.popups.items[i - 1];
            if (i >= 2) {
                const popup_prev = sd.popups.items[i - 2];
                popup.update();
                try popup.render(popup_prev);
            } else {
                popup.update();
                try popup.render(null);
            }
            if (popup.lifetime <= 0) {
                _ = sd.popups.orderedRemove(i - 1);
            }
            i -= 1;
        }
    }
    print("Ending the client\n", .{});
}
