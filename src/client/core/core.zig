const std = @import("std");
const ui = @import("../ui/ui.zig");
const rl = @import("raylib");
const sc = @import("../screen/screen.zig");
const aids = @import("aids");
const comm = aids.v2.comm;
const Logging = aids.Logging;
const Stab = aids.Stab;

const str_allocator = std.heap.page_allocator;

// Data to share between threads
pub const SharedData = struct {
    m: std.Thread.Mutex,
    should_exit: bool,
    messages: std.ArrayList(ui.Display.Message),
    client: Client = undefined, // Client gets defined after the username is entered
    connected: bool,
    cond: std.Thread.Condition,
    popups: std.ArrayList(ui.SimplePopup),
    sizing: sc.UI_SIZING = sc.UI_SIZING{},
    ui: sc.UI_ELEMENTS,

    pub fn updateSizing(self: *@This(), SW: i32, SH: i32) void {
        self.m.lock();
        defer self.m.unlock();
        self.sizing.update(SW, SH);
        self.client.font_size = self.sizing.font_size;
    }

    pub fn setConnected(self: *@This(), val: bool) void {
        self.m.lock();
        defer self.m.unlock();
        self.connected = val;
    }

    pub fn setShouldExit(self: *@This(), should: bool) void {
        self.m.lock();
        defer self.m.unlock();
        self.should_exit = should;
    }
    pub fn pushPopup(self: *@This(), popup: ui.SimplePopup) void {
        self.m.lock();
        defer self.m.unlock();

        if (popup.pos == .BOTTOM_FIX) {
            for (self.popups.items, 0..self.popups.items.len) |p, i| {
                if (p.pos == .BOTTOM_FIX) {
                    self.popups.items[i] = popup;
                    return;
                }
            }
        }
        _ = self.popups.append(popup) catch 1;
    }
    pub fn pushMessage(self: *@This(), msg: ui.Display.Message) !void {
        self.m.lock();
        defer self.m.unlock();
        try self.messages.append(msg);
    }

    // TODO: move to comm client action
    pub fn establishConnection(self: *@This(), allocator: std.mem.Allocator, username: []const u8, hostname: []const u8, port: u16) void {
        self.m.lock();
        defer self.m.unlock();

        var err_popup = ui.SimplePopup.init(self.client.font, .TOP_CENTER, self.client.FPS * 2);
        err_popup.setTextColor(rl.Color.red);
        var popup_msg: []u8 = undefined;
        const addr = std.net.Address.resolveIp(hostname, port) catch |err| { // TODO: dest_addr
            std.log.err("client::connect::addr: {any}", .{err});
            popup_msg = std.fmt.allocPrint(str_allocator, "Could not resolve ip address: `{s}:{d}`", .{ hostname, port }) catch |alloc_err| {
                std.log.err("{}", .{alloc_err});
                std.posix.exit(1);
            };
            err_popup.text = popup_msg;
            std.log.err("{any}", .{err});
            _ = self.popups.append(err_popup) catch |errapp| {
                std.log.err("login-screen::update: {}", .{errapp});
                std.posix.exit(1);
            };
            return;
        };
        const dst_addr = aids.cmn.address_as_str(addr); // TODO: dest_addr_str
        std.debug.print("Requesting connection to `{s}`\n", .{dst_addr});
        const stream = std.net.tcpConnectToAddress(addr) catch |err| {
            std.log.err("client::connect::stream: {any}", .{err});
            std.log.err("client::connect::addr: {any}", .{err});
            err_popup.setTextColor(rl.Color.red);
            popup_msg = std.fmt.allocPrint(str_allocator, "Could not resolve tcp connection to address: `{s}`", .{dst_addr}) catch |alloc_err| {
                std.log.err("{}", .{alloc_err});
                std.posix.exit(1);
            };
            err_popup.text = popup_msg;
            std.log.err("{any}", .{err});
            _ = self.popups.append(err_popup) catch |errapp| {
                std.log.err("39::login-screen::update: {}", .{errapp});
                std.posix.exit(1);
            };
            return;
        };
        // request connection
        const reqp = comm.Protocol{
            .type = .REQ,
            .action = .COMM,
            .status_code = .OK,
            .sender_id = "client",
            .src_addr = "client",
            .dest_addr = dst_addr,
            .body = username,
        };
        reqp.dump(self.client.log_level);
        _ = reqp.transmit(stream) catch 1;

        const resp = comm.collect(allocator, stream) catch |err| {
            std.log.err("client::connect: {any}", .{err});
            std.posix.exit(1);
        };
        resp.dump(self.client.log_level);

        if (resp.status_code == .OK) {
            var peer_spl = std.mem.split(u8, resp.body, "|");
            const id = peer_spl.next().?;
            const username_ = peer_spl.next().?;
            self.client.setUsername(username_);
            self.client.setID(id);
            self.client.stream = stream;
            self.client.server_addr = addr;
            self.client.server_addr_str = dst_addr;
            self.client.client_addr_str = resp.dest_addr;
            self.connected = true;

            const succ_str = std.fmt.allocPrintZ(allocator, "Client connected successfully to `{s}` :)", .{self.client.server_addr_str}) catch |err| {
                std.log.err("SharedData::establishConnection::succ_str: {any}", .{err});
                std.posix.exit(1);
            };

            // TODO: does SimplePopup free allocated text ??
            var succ_conn_popup = ui.SimplePopup.init(self.client.font, .TOP_CENTER, self.client.FPS * 3);
            succ_conn_popup.text = succ_str; // TODO: SimplePopup.setText
            succ_conn_popup.setTextColor(rl.Color.green);
            _ = self.popups.append(succ_conn_popup) catch 1; // TODO: sd.pushPopup
        } else {
            self.connected = false;
            std.log.err("server error when creating client", .{});
            std.posix.exit(1);
        }
        self.cond.signal();
    }
    pub fn closeConnection(self: *@This()) void {
        self.m.lock();
        defer self.m.unlock();
        // TODO: This should be client action
        const reqp = comm.Protocol{
            .type = .REQ,
            .action = .COMM_END,
            .status_code = .OK,
            .sender_id = self.client.id,
            .src_addr = self.client.client_addr_str,
            .dest_addr = self.client.server_addr_str,
            .body = "OK",
        };
        self.client.sendRequestToServer(reqp);

        self.connected = false;
        self.client.username = undefined;
        self.client.id = undefined;
        self.client.stream.close();
        self.client.server_addr_str = undefined;
        self.client.client_addr_str = undefined;
        self.client.server_addr = undefined;
        self.client.client_addr = undefined;

        var close_connection_popup = ui.SimplePopup.init(self.client.font, .TOP_CENTER, self.client.FPS * 4);
        close_connection_popup.text = "Server connection terminated"; // TODO: SimplePopup.setText
        close_connection_popup.setTextColor(rl.Color.orange);
        _ = self.popups.append(close_connection_popup) catch 1; // TODO: self.pushPopup
    }
};

pub const CommandData = struct {
    sd: *SharedData,
    body: []const u8,
    ui_elements: sc.UI_ELEMENTS,
};

pub const Client = struct {
    id: []const u8 = undefined,
    username: []const u8 = undefined,
    Commander: Stab.Commander(Stab.Command(CommandData)),
    Actioner: Stab.Actioner(SharedData),
    log_level: Logging.Level,
    // Should the client be it's own server ?
    stream: std.net.Stream = undefined,
    server_addr: std.net.Address = undefined,
    server_addr_str: []const u8 = "404: not found",
    client_addr: std.net.Address = undefined,
    client_addr_str: []const u8 = "404: not found",
    font: rl.Font,
    font_size: f32,
    FPS: usize,
    pub fn init(allocator: std.mem.Allocator, font: rl.Font, log_level: Logging.Level, FPS: usize) Client {
        const commander = Stab.Commander(Stab.Command(CommandData)).init(allocator);
        const actioner = Stab.Actioner(SharedData).init(allocator);
        return Client{
            .log_level = log_level,
            .font = font,
            .font_size = 0,
            .FPS = FPS,
            .Commander = commander,
            .Actioner = actioner,
        };
    }
    pub fn deinit(self: *@This()) void {
        self.username = undefined;
        self.id = undefined;
        self.stream.close();
        self.server_addr_str = undefined;
        self.client_addr_str = undefined;
        self.server_addr = undefined;
        self.client_addr = undefined;
        self.Commander.deinit();
        self.Actioner.deinit();
    }
    pub fn setUsername(self: *@This(), username: []const u8) void {
        self.username = username;
    }
    pub fn setID(self: *@This(), id: []const u8) void {
        self.id = id;
    }
    pub fn asStr(self: @This(), allocator: std.mem.Allocator) [:0]const u8 {
        const stats = std.fmt.allocPrintZ(allocator, "Client:\n" ++
            "    username: {s}\n" ++
            "    id: {s}\n" ++
            "    server_address: {s}\n" ++
            "    client_address: {s}", .{ self.username, self.id, self.server_addr_str, self.client_addr_str }) catch |err| {
            std.log.err("client::asStr: {any}", .{err});
            std.posix.exit(1);
        };
        return stats;
    }

    /// TODO: depricated
    pub fn dump(self: @This()) void {
        std.debug.print("------------------------------------\n", .{});
        std.debug.print("Client {{\n", .{});
        std.debug.print("    id: `{s}`\n", .{self.id});
        std.debug.print("    username: `{s}`\n", .{self.username});
        std.debug.print("    server_addr: `{s}`\n", .{aids.address_as_str(self.server_addr)});
        std.debug.print("    client_addr: `{s}`\n", .{self.client_addr});
        std.debug.print("}}\n", .{});
        std.debug.print("------------------------------------\n", .{});
    }

    pub fn sendRequestToServer(self: @This(), request: comm.Protocol) void {
        // Open a sterm to the server
        const req_stream = std.net.tcpConnectToAddress(self.server_addr) catch |err| {
            std.log.err("client::sendRequestToServer: {any}", .{err});
            std.posix.exit(1);
        };
        defer req_stream.close();
        // send protocol to server
        request.dump(self.log_level);
        _ = request.transmit(req_stream) catch 1;
    }
};
