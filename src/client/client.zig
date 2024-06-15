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
const InputBox = @import("ui/input-box.zig");
const rlb = @import("ui/button.zig");
const Display = @import("ui/display.zig");
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
fn accept_connections(sd: *core.SharedData, messages: *std.ArrayList(Display.Message)) !void {
    const addr_str = sd.client.server_addr_str;
    while (!sd.should_exit) {
        const resp = try Protocol.collect(str_allocator, sd.client.stream);
        resp.dump(sd.client.log_level);
        if (resp.is_response()) {
            if (resp.is_action(Protocol.Act.COMM_END)) {
                // TODO: COMM client action
                if (resp.status_code == Protocol.StatusCode.OK) {
                    sd.setShouldExit(true);
                }
            } else if (resp.is_action(Protocol.Act.GET_PEER)) {
                // TODO: GET_PEER client action
                if (resp.status_code == Protocol.StatusCode.OK) {
                    std.log.err("not implemented", .{});
                }
            } else if (resp.is_action(Protocol.Act.MSG)) {
                // TODO: MSG client action
                if (resp.status_code == Protocol.StatusCode.OK) {
                    // construct protocol to get peer data
                    const reqp = Protocol.init(
                        Protocol.Typ.REQ, // type
                        Protocol.Act.GET_PEER, // action
                        Protocol.StatusCode.OK, // status code
                        sd.client.id, // sender id
                        sd.client.client_addr_str, // src address
                        addr_str, // destination address
                        resp.sender_id, //body
                    );
                    sd.client.sendRequestToServer(reqp);

                    // collect GET_PEER response
                    const np = try Protocol.collect(str_allocator, sd.client.stream);
                    np.dump(sd.client.log_level);

                    var un_spl = mem.split(u8, np.body, "#");
                    const unn = un_spl.next().?; // user name
                    //const unh = un_spl.next().?; // username hash

                    // print recieved message
                    //const msg_text = try std.fmt.allocPrint(
                    //    str_allocator,
                    //    "{s}" ++ tclr.paint_hex("#555555", "#{s}") ++ ": {s}\n",
                    //    .{ unn, unh, resp.body }
                    //);
                    const msg_text = try std.fmt.allocPrint(
                        str_allocator,
                        "{s}",
                        .{ resp.body }
                    );
                    const message = Display.Message{ .author=unn, .text = msg_text };
                    _ = try messages.append(message);
                } else {
                    resp.dump(sd.client.log_level);
                }
            }
        } else if (resp.is_request()) {
            if (resp.is_action(Protocol.Act.COMM)) {
                // TODO: COMM client action
                if (resp.status_code == Protocol.StatusCode.OK) {
                    std.log.err("not implemented", .{});
                }
            } else if (resp.is_action(Protocol.Act.NTFY_KILL)) {
                // TODO: NTFY_KILL client action
                if (resp.status_code == Protocol.StatusCode.OK) {
                    std.log.err("not implemented", .{});
                }
            } else if (resp.is_action(Protocol.Act.COMM_END)) {
                // TODO: COMM_END client action
                if (resp.status_code == Protocol.StatusCode.OK) {
                    sd.setShouldExit(true);
                    return;
               }
            } 
        } else if (resp.type == Protocol.Typ.ERR) {
            //sd.client.stream.close();
            resp.dump(sd.client.log_level);
            break;
        }
    }
    print("Ending `accepting_connection`\n", .{});
}

/// TODO: convert to client action
fn sendMessage(client: Client, message_box: *InputBox, message_display: *Display) void {
    const msg = message_box.getCleanValue();
    // handle sending a message
    const reqp = Protocol.init(
        Protocol.Typ.REQ,
        Protocol.Act.MSG,
        Protocol.StatusCode.OK,
        client.id,
        client.client_addr_str,
        client.server_addr_str,
        msg,
    );
    client.sendRequestToServer(reqp);
    const q = std.fmt.allocPrint(str_allocator, "{s}", .{msg}) catch |err| {
        std.log.err("`allocPrint`: {any}", .{err});
        std.posix.exit(1);
    };

    var un_spl = mem.split(u8, client.username, "#");
    const unn = un_spl.next().?; // user name
    //const unh = un_spl.next().?; // username hash
    const message = Display.Message{
        .author=unn,
        .text=q,
    };
    _ = message_display.messages.append(message) catch |err| {
        std.log.err("`message_display`: {any}", .{err});
        std.posix.exit(1);
    };
    _ = message_box.clean();
}

/// TODO: convert to client action
fn pingClient(client: Client, message_box: *InputBox, message_display: *Display) void {
    _ = client;
    _ = message_display;
    var splits = mem.splitScalar(u8, message_box.getCleanValue(), ' ');
    _ = splits.next(); // action caller
    const opt_username = splits.next();
    if (opt_username) |username| {
        if (username.len > 0) {
            std.log.warn("un: `{s}`", .{username});
            std.log.err("`pingClient` not implemented", .{});
            std.posix.exit(1);
        } else {
            std.log.warn("missing peer username", .{});
        }
        //const reqp = Protocol.init(
        //    Protocol.Typ.REQ,
        //    Protocol.Act.PING,
        //    Protocol.StatusCode.OK,
        //    client.id,
        //    client.client_addr,
        //    cmn.address_as_str(client.server_addr),
        //    username,
        //);
        //send_request(client.server_addr, reqp) catch |err| {
        //    std.log.err("`send_request`: {any}", .{err});
        //    std.posix.exit(1);
        //};
        // TODO: collect response
        // TODO: print peer data to message_display
        //const message = rld.Message{
        //    .author=unn,
        //    .text=q,
        //};
        //_ = message_display.messages.append(message) catch |err| {
        //    std.log.err("`message_display`: {any}", .{err});
        //    std.posix.exit(1);
        //};
        //_ = message_box.clean();
    } else {
        std.log.warn("missing peer username", .{});
    }
}

fn renderMessage(sd: *core.SharedData, message_box: *InputBox, message_display: *Display, msg: []const u8) void {
    const baked_msg = std.fmt.allocPrint(str_allocator, "{s}", .{msg}) catch |err| {
        std.log.err("`allocPrint`: {any}", .{err});
        std.posix.exit(1);
    };
    var un_spl = std.mem.split(u8, sd.client.username, "#");
    const unn = un_spl.next().?; // user name
    //const unh = un_spl.next().?; // username hash
    const message = Display.Message{
        .author=unn,
        .text=baked_msg,
    };
    _ = message_display.messages.append(message) catch |err| {
        std.log.err("`message_display`: {any}", .{err});
        std.posix.exit(1);
    };
    _ = message_box.clean();
}

/// TODO: introduce client action
const Action = *const fn (*core.SharedData, *InputBox, *Display) void;

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

    //_ = try client_acts.put(":msg", sendMessage);
    //_ = try client_acts.put(":ping", pingClient);
    client.Commander.add(":exit", ClientCommand.EXIT_CLIENT);

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

    var connected = false;
    var response_counter: usize = FPS*1;
    var frame_counter: usize = 0;
    var message_box = InputBox{};
    var user_login_box = InputBox{};
    var user_login_btn = rlb.Button{ .text="Enter", .color = rl.Color.light_gray };
    var message_display = Display{};
    message_display.allocMessages(gpa_allocator);
    defer message_display.messages.deinit();
    // I think detaching and or joining threads is not needed becuse I handle ending of threads with core.SharedData.should_exit
    var thread_pool: [1]std.Thread = undefined;
    var sd = core.SharedData{
        .m = std.Thread.Mutex{},
        .should_exit = false,
        .messages = message_display.messages,
        .client = client,
    };
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
        if (connected) {
            _ = message_box.setRec(20, sh - 100 - font_size/2, sw - 40, 50 + font_size/2); 
            _ = message_display.setRec(20, 200, sw - 40, sh - 400); 
            if (message_box.isClicked()) {
                _ = message_box.setEnabled(true);
            } else {
                if (rl.isMouseButtonPressed(.mouse_button_left)) {
                    _ = message_box.setEnabled(false);
                }
            }
        } else {
            _ = user_login_box.setRec(sw/2 - sw/4, 200 + font_size/2, sw/2, 50 + font_size/2); 
            user_login_btn.setRec(user_login_box.rec.x + sw/5.5, user_login_box.rec.y+140, sw/8, 90);
            if (user_login_box.isClicked()) {
                _ = user_login_box.setEnabled(true);
            } else {
                if (rl.isMouseButtonPressed(.mouse_button_left)) {
                    _ = user_login_box.setEnabled(false);
                }
            }
            if (user_login_btn.isMouseOver()) {
                user_login_btn.color = rl.Color.dark_gray;
                if (user_login_btn.isClicked()) {
                    const username = mem.sliceTo(&user_login_box.value, 0);
                    sd.client.setUsername(username);
                    sd.client.connect(str_allocator, server_addr, server_port);
                    connected = true;
                    _ = message_box.setEnabled(true);
                    _ = user_login_box.setEnabled(false);
                    thread_pool[0] = try std.Thread.spawn(.{}, accept_connections, .{ &sd, &message_display.messages });
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
            if (rl.isKeyPressed(.key_backspace)) {
                _ = user_login_box.pop();
            } 
            if (rl.isKeyDown(.key_enter)) {
                // Start the a separate thread that listens for inncomming messages from the server
                const username = mem.sliceTo(&user_login_box.value, 0);
                sd.client.setUsername(username);
                sd.client.connect(str_allocator, server_addr, server_port);
                connected = true;
                _ = message_box.setEnabled(true);
                _ = user_login_box.setEnabled(false);
                thread_pool[0] = try std.Thread.spawn(.{}, accept_connections, .{ &sd, &message_display.messages });
            }
        }
        if (message_box.enabled) {
            if (message_box.isKeyPressed(.key_backspace)) {
                // remove char from message box
                _ = message_box.pop();
            } 
            if (message_box.isKeyPressed(.key_enter)) {
                // handle client actions
                const mcln = message_box.getCleanValue();
                if (mcln.len > 0) {
                    var splits = mem.splitScalar(u8, mcln, ' ');
                    if (splits.next()) |frst| {
                        if (client.Commander.get(frst)) |action| {
                            action.executor(frst, &sd);
                        } else {
                            // default action
                            const msg = message_box.getCleanValue();
                            ClientAction.MSG.transmit.?.request(Protocol.TransmitionMode.UNICAST, &sd, msg);
                            renderMessage(&sd, &message_box, &message_display, msg);
                        }
                    }
                }
            }
        }
        rl.clearBackground(rl.Color.init(18, 18, 18, 255));
        if (connected) {
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
                try message_display.render(str_allocator, font, font_size, frame_counter);
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
