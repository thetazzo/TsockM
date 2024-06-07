const std = @import("std");
const ptc = @import("ptc");
const cmn = @import("cmn");
const tclr = @import("text_color");
const ib = @import("input-box.zig");
const rlb = @import("button.zig");
const rld = @import("display.zig");
const rl = @import("raylib");
const mem = std.mem;
const net = std.net;
const print = std.debug.print;

const str_allocator = std.heap.page_allocator;

const LOG_LEVEL = ptc.LogLevel.SILENT;

const Client = struct {
    id: []const u8,
    username: []const u8,
    stream: net.Stream,
    server_addr: net.Address,
    client_addr: ptc.Addr,

    pub fn dump(self: @This()) void {
        print("------------------------------------\n", .{});
        print("Client {{\n", .{});
        print("    id: `{s}`\n", .{self.id});
        print("    username: `{s}`\n", .{self.username});
        print("    server_addr: `{s}`\n", .{cmn.address_as_str(self.server_addr)});
        print("    client_addr: `{s}`\n", .{self.client_addr});
        print("}}\n", .{});
        print("------------------------------------\n", .{});
    }
};

fn clientStats(client: Client) ![]const u8 {
    const username    = try std.fmt.allocPrint(str_allocator, "username: {s}\n", .{client.username});
    const id          = try std.fmt.allocPrint(str_allocator, "id: {s}\n", .{client.id});
    const server_addr = try std.fmt.allocPrint(str_allocator, "server_address: {s}\n", .{cmn.address_as_str(client.server_addr)});
    const client_addr = try std.fmt.allocPrint(str_allocator, "client address: {s}\n", .{client.client_addr});
    const stats = try std.fmt.allocPrint(str_allocator, "{s}{s}{s}{s}", .{username, id, server_addr, client_addr});
    return stats;
}

fn print_usage() void {
    print("COMMANDS:\n", .{});
    print("    * :msg <message> .... boradcast the message to all users\n", .{});
    print("    * :gp <peer_id> ..... request peer data from server\n", .{});
    print("    * :exit ............. terminate the program\n", .{});
    print("    * :info ............. print information about the client\n", .{});
    print("    * :cc ,,............. clear screen\n", .{});
}

fn request_connection(address: []const u8, port: u16, username: []const u8) !Client {
    const addr = try net.Address.resolveIp(address, port);
    print("Requesting connection to `{s}`\n", .{cmn.address_as_str(addr)});
    const stream = try net.tcpConnectToAddress(addr);
    const dst_addr = cmn.address_as_str(addr);
    // request connection
    const reqp = ptc.Protocol.init(
        ptc.Typ.REQ,
        ptc.Act.COMM,
        ptc.StatusCode.OK,
        "client",
        "client",
        dst_addr,
        username,
    );
    reqp.dump(LOG_LEVEL);
    _ = ptc.prot_transmit(stream, reqp);

    const resp = try ptc.prot_collect(str_allocator, stream);
    resp.dump(LOG_LEVEL);

    if (resp.status_code == ptc.StatusCode.OK) {
        var peer_spl = mem.split(u8, resp.body, "|");
        const id = peer_spl.next().?;
        const username_ = peer_spl.next().?;

        // construct the client
        return Client{
            .id = id,
            .username = username_,
            .stream = stream,
            .server_addr = addr,
            .client_addr = resp.dst,
        };
    } else {
        std.log.err("server error when creating client", .{});
        std.posix.exit(1);
    }
}

fn send_request(addr: net.Address, req: ptc.Protocol) !void {
    // Open a sterm to the server
    const req_stream = try net.tcpConnectToAddress(addr);
    defer req_stream.close();

    // send protocol to server
    req.dump(LOG_LEVEL);
    _ = ptc.prot_transmit(req_stream, req);
}

// Data to share between threads
const SharedData = struct {
    m: std.Thread.Mutex,
    should_exit: bool,

    pub fn update_value(self: *@This(), should: bool) void {
        self.m.lock();
        defer self.m.unlock();

        self.should_exit = should;
    }
};

fn listen_for_comms(sd: *SharedData, client: *Client) !void {
    const addr_str = cmn.address_as_str(client.server_addr);
    while (true) {
        const resp = try ptc.prot_collect(str_allocator, client.stream);
        resp.dump(LOG_LEVEL);
        if (resp.is_response()) {
            if (resp.is_action(ptc.Act.COMM_END)) {
                if (resp.status_code == ptc.StatusCode.OK) {
                    client.stream.close();
                    print("Server connection terminated.\n", .{});
                    break;
                }
            } else if (resp.is_action(ptc.Act.GET_PEER)) {
                if (resp.status_code == ptc.StatusCode.OK) {
                    const peer_name = resp.body;
                    print("Peer name is: {s}\n", .{peer_name});
                }
            } else if (resp.is_action(ptc.Act.MSG)) {
                if (resp.status_code == ptc.StatusCode.OK) {
                    // construct protocol to get peer data
                    const reqp = ptc.Protocol.init(
                        ptc.Typ.REQ, // type
                        ptc.Act.GET_PEER, // action
                        ptc.StatusCode.OK, // status code
                        client.id, // sender id
                        "client", // src address
                        addr_str, // destination address
                        resp.sender_id, //body
                    );
                    try send_request(client.server_addr, reqp);

                    // collect GET_PEER response
                    const np = try ptc.prot_collect(str_allocator, client.stream);
                    np.dump(LOG_LEVEL);

                    var un_spl = mem.split(u8, np.body, "#");
                    const unn = un_spl.next().?; // user name
                    const unh = un_spl.next().?; // username hash

                    // print recieved message
                    print("{s}" ++ tclr.paint_hex("#555555", "#{s}") ++ ": {s}\n", .{ unn, unh, resp.body });
                } else {
                    resp.dump(LOG_LEVEL);
                }
            }
        } else if (resp.is_request()) {
            if (resp.is_action(ptc.Act.COMM)) {
                if (resp.status_code == ptc.StatusCode.OK) {
                    // protocol to say communication is OK
                    const msgp = ptc.Protocol.init(
                        ptc.Typ.RES,
                        ptc.Act.COMM,
                        ptc.StatusCode.OK,
                        client.id,
                        "client",
                        addr_str,
                        "OK"
                    );
                    try send_request(client.server_addr, msgp);
                }
            } else if (resp.is_action(ptc.Act.NTFY_KILL)) {
                if (resp.status_code == ptc.StatusCode.OK) {
                    // construct protocol to get peer data
                    const reqp = ptc.Protocol.init(
                        ptc.Typ.REQ, // type
                        ptc.Act.GET_PEER, // action
                        ptc.StatusCode.OK, // status code
                        client.id, // sender id
                        "client", // src address
                        addr_str, // destination address
                        resp.body, //body
                    );
                    try send_request(client.server_addr, reqp);

                    // collect GET_PEER response
                    const np = try ptc.prot_collect(str_allocator, client.stream);
                    np.dump(LOG_LEVEL);

                    var un_spl = mem.split(u8, np.body, "#");
                    const unn = un_spl.next().?; // user name
                    const unh = un_spl.next().?; // username hash
                    print("Peer `{s}" ++ tclr.paint_hex("#555555", "#{s}") ++ "` has died\n", .{unn, unh});
                }
            } else if (resp.is_action(ptc.Act.COMM_END)) {
                if (resp.status_code == ptc.StatusCode.OK) {
                    client.stream.close();
                    print("Server connection terminated. Press <ENTER> to close the program.\n", .{});
                    break;
                }
            } 
        } else if (resp.type == ptc.Typ.ERR) {
            //client.stream.close();
            resp.dump(LOG_LEVEL);
            break;
        }
    }
    sd.update_value(true);
}

fn extract_command_val(cs: []const u8, cmd: []const u8) []const u8 {
    var splits = mem.split(u8, cs, cmd);
    _ = splits.next().?; // the `:msg` part
    const val = mem.trimLeft(u8, splits.next().?, " \n");
    if (val.len <= 0) {
        std.log.err("missing action value", .{});
        print_usage();
    }
    return val;
}

fn read_cmd(sd: *SharedData, client: *Client) !void {
    const addr_str = cmn.address_as_str(client.server_addr);
    print("Enter action here:\n", .{});
    while (!sd.should_exit) {
        // read for command
        var buf: [256]u8 = undefined;
        const stdin = std.io.getStdIn().reader();
        if (try stdin.readUntilDelimiterOrEof(buf[0..], '\n')) |user_input| {
            if (sd.should_exit) {
                break;
            }
            // Handle different commands
            if (mem.startsWith(u8, user_input, ":msg")) {
                const msg = extract_command_val(user_input, ":msg");
                // construct message protocol
                const reqp = ptc.Protocol.init(
                    ptc.Typ.REQ,
                    ptc.Act.MSG,
                    ptc.StatusCode.OK,
                    client.id,
                    "client",
                    addr_str,
                    msg,
                );
                try send_request(client.server_addr, reqp);
            } else if (mem.startsWith(u8, user_input, ":gp")) {
                const pid = extract_command_val(user_input, ":gp");
                // construct message protocol
                const reqp = ptc.Protocol.init(
                    ptc.Typ.REQ,
                    ptc.Act.GET_PEER,
                    ptc.StatusCode.OK,
                    client.id,
                    "client",
                    addr_str,
                    pid,
                );
                try send_request(client.server_addr, reqp);
            } else if (mem.eql(u8, user_input, ":info")) {
                client.dump();
            } else if (mem.eql(u8, user_input, ":exit")) {
                const reqp = ptc.Protocol.init(
                    ptc.Typ.REQ,
                    ptc.Act.COMM_END,
                    ptc.StatusCode.OK,
                    client.id,
                    "client",
                    addr_str,
                    "",
                );
                sd.update_value(true);
                try send_request(client.server_addr, reqp);
            } else if (mem.eql(u8, user_input, ":cc")) {
                try cmn.screen_clear();
                client.dump();
            } else if (mem.eql(u8, user_input, ":help")) {
                print_usage();
            } else {
                print("Unknown command: `{s}`\n", .{user_input});
                print_usage();
            }
        } else {
            print("Unreachable, maybe?\n", .{});
        }
    }
    print("exiting read_cmd\n", .{});
}

fn isKeyPressed() bool
{
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

fn request_connection_from_input(input_box: *ib.InputBox, server_addr: []const u8, server_port: u16) !Client {
    // request connection
    const username = mem.sliceTo(&input_box.value, 0);
    const client = try request_connection(server_addr, server_port, username);
    _ = input_box.setEnabled(false);
    return client;
}

const F = 160;
pub fn start(server_addr: [:0]const u8, server_port: u16) !void {
    const SW = 16*F;
    const SH = 9*F;
    rl.initWindow(SW, SH, "TsockM");
    defer rl.closeWindow();

    const font = loadExternalFont("./src/assets/font/IosevkaTermSS02-SemiBold.ttf");

    const FPS = 20;
    rl.setTargetFPS(FPS);

    var client: Client = undefined;
    var connected = false;
    var response_counter: usize = FPS*1;
    var frame_counter: usize = 0;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_allocator = gpa.allocator();

    var message_box = ib.InputBox{};
    var user_login_box = ib.InputBox{};
    var user_login_btn = rlb.Button{ .text="Enter", .color = rl.Color.light_gray };
    var message_display = rld.Display{};
    message_display.allocMessages(gpa_allocator);
    while (!rl.windowShouldClose()) {
        const sw = @as(f32, @floatFromInt(rl.getScreenWidth()));
        const sh = @as(f32, @floatFromInt(rl.getScreenHeight()));
        const font_size = 60;
        const window_extended = sh > SH;

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
            _ = user_login_box.setRec(sw/2 - 200, 200 + font_size/2, 800, 50 + font_size/2); 
            user_login_btn.setRec(user_login_box.rec.x, user_login_box.rec.y+140, 200, 90);
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
                    client = try request_connection_from_input(&user_login_box, server_addr, server_port);
                    connected = true;
                    _ = message_box.setEnabled(true);
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
            if (rl.isKeyDown(.key_backspace)) {
                _ = user_login_box.pop();
            } 
            if (rl.isKeyDown(.key_enter)) {
                client = try request_connection_from_input(&user_login_box, server_addr, server_port);
                connected = true;
            }
        }
        if (message_box.enabled) {
            if (rl.isKeyDown(.key_backspace)) {
                _ = message_box.pop();
            } 
            // TODO: message_box::handle_commands
            if (rl.isKeyPressed(.key_enter)) {
                const mcln = mem.sliceTo(&message_box.value, 170);
                if (mcln.len > 0) {
                    const addr_str = cmn.address_as_str(client.server_addr);
                    const reqp = ptc.Protocol.init(
                        ptc.Typ.REQ,
                        ptc.Act.MSG,
                        ptc.StatusCode.OK,
                        client.id,
                        "client",
                        addr_str,
                        mcln,
                    );
                    try send_request(client.server_addr, reqp);
                    const q = try std.fmt.allocPrint(str_allocator, "{s}", .{mcln});
                    const message = rld.Message{
                        .author=client.username,
                        .text=q,
                    };
                    _ = try message_display.messages.append(message);
                    _ = message_box.clean();
                }
            }
        }
        rl.clearBackground(rl.Color.init(18, 18, 18, 255));
        if (connected) {
            // Messaging screen
            // Draw successful connection
            var buf: [256]u8 = undefined;
            const succ_str = try std.fmt.bufPrintZ(&buf, "Client connected successfully to `{s}:{d}` :)\n", .{server_addr, server_port});
            if (response_counter > 0) {
                const sslen = rl.measureTextEx(font, succ_str, font_size, 0).x;
                rl.drawTextEx(font, succ_str, rl.Vector2{.x=sw/2 - sslen/2, .y=sh/2 - sh/4}, font_size, 0, rl.Color.green);
                response_counter -= 1;
            } else {
                // Draw client information
                const client_str  = try std.fmt.bufPrintZ(&buf, "{s}\n", .{try clientStats(client)});
                try message_display.render(str_allocator, font, font_size, frame_counter);
                rl.drawTextEx(font, client_str, rl.Vector2{.x=40, .y=40}, font_size/2, 0, rl.Color.light_gray);
                try message_box.render(window_extended, font, font_size, frame_counter);
            }
        } else {
            // Login screen
            var buf: [256]u8 = undefined;
            const title_str = try std.fmt.bufPrintZ(&buf, "TsockM", .{});
            rl.drawTextEx(
                font,
                title_str,
                rl.Vector2{.x=user_login_box.rec.x - 65, .y=50},
                font_size * 1.75,
                0,
                rl.Color.light_gray
            );
            const succ_str = try std.fmt.bufPrintZ(&buf, "Enter your username:", .{});
            rl.drawTextEx(
                font,
                succ_str,
                rl.Vector2{.x=user_login_box.rec.x - 520, .y=user_login_box.rec.y + user_login_box.rec.height/9},
                font_size,
                0,
                rl.Color.light_gray
            );
            try user_login_box.render(window_extended, font, font_size, frame_counter);
            try user_login_btn.render(font, font_size);
        }
    }

    //var buf: [256]u8 = undefined;
    //const stdin = std.io.getStdIn().reader();
    //if (try stdin.readUntilDelimiterOrEof(buf[0..], '\n')) |user_input| {
    //    // communication request
    //    defer print("Client stopped\n", .{});
    //    var sd = SharedData{
    //        .m = std.Thread.Mutex{},
    //        .should_exit = false,
    //    };
    //    {
    //        const t1 = try std.Thread.spawn(.{}, listen_for_comms, .{ &sd, &client });
    //        defer t1.join();
    //        errdefer t1.join();
    //        const t2 = try std.Thread.spawn(.{}, read_cmd, .{ &sd, &client });
    //        defer t2.join();
    //        errdefer t2.join();
    //    }
    //}
}
