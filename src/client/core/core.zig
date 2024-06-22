const std = @import("std");
const ui = @import("../ui/ui.zig");
const rl = @import("raylib");
const sc = @import("../screen/screen.zig");
const aids = @import("aids");
const Protocol = aids.Protocol;
const Logging = aids.Logging;
const Stab = aids.Stab;

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

    pub fn pushMessage(self: *@This(), msg: ui.Display.Message) !void {
        self.m.lock();
        defer self.m.unlock();
        try self.messages.append(msg);
    }

    // TODO: move to comm client action
    pub fn establishConnection(self: *@This(), allocator: std.mem.Allocator, username: []const u8, hostname: []const u8, port: u16) void {
        self.m.lock();
        defer self.m.unlock();
        const addr = std.net.Address.resolveIp(hostname, port) catch |err| {
            std.log.err("51::client::connect::addr: {any}", .{err});
            var invalid_sip_popup = ui.SimplePopup.init(self.client.font, &self.sizing, 30*2);
            invalid_sip_popup.setTextColor(rl.Color.red);
            invalid_sip_popup.text = "Connection to server failed";
            std.log.err("{any}", .{err});
            _ = self.popups.append(invalid_sip_popup) catch |errapp| {
                std.log.err("39::login-screen::update: {}", .{errapp});
                std.posix.exit(1);
            };
            return;
        };
        std.debug.print("Requesting connection to `{s}:{d}`\n", .{hostname, port});
        const stream = std.net.tcpConnectToAddress(addr) catch |err| {
            std.log.err("64::client::connect::stream: {any}", .{err});
            std.log.err("51::client::connect::addr: {any}", .{err});
            // TODO: fix naming
            var conn_refused_popup = ui.SimplePopup.init(self.client.font, &self.sizing, 30*2);
            conn_refused_popup.setTextColor(rl.Color.red);
            conn_refused_popup.text = "Could not connect to server";
            std.log.err("{any}", .{err});
            _ = self.popups.append(conn_refused_popup) catch |errapp| {
                std.log.err("39::login-screen::update: {}", .{errapp});
                std.posix.exit(1);
            };
            return;
        };
        const dst_addr = aids.cmn.address_as_str(addr);
        // request connection
        const reqp = Protocol.init(
            Protocol.Typ.REQ,
            Protocol.Act.COMM,
            Protocol.StatusCode.OK,
            "client",
            "client",
            dst_addr,
            username,
        );
        reqp.dump(self.client.log_level);
        _ = Protocol.transmit(stream, reqp);

        const resp = Protocol.collect(allocator, stream) catch |err| {
            std.log.err("client::connect: {any}", .{err});
            std.posix.exit(1);
        };
        resp.dump(self.client.log_level);

        if (resp.status_code == Protocol.StatusCode.OK) {
            var peer_spl = std.mem.split(u8, resp.body, "|");
            const id = peer_spl.next().?;
            const username_ = peer_spl.next().?;
            self.client.setUsername(username_);
            self.client.setID(id);
            self.client.stream = stream;
            self.client.server_addr = addr;
            self.client.server_addr_str = dst_addr;
            self.client.client_addr_str = resp.dst;
            self.connected = true;
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

        //self.should_exit = true;

        self.connected = false;
        self.client.username = undefined;
        self.client.id = undefined;
        self.client.stream.close();
        self.client.server_addr_str = undefined;
        self.client.client_addr_str = undefined;
        self.client.server_addr = undefined;
        self.client.client_addr = undefined;

        var close_connection_popup = ui.SimplePopup.init(self.client.font, &self.sizing, 30*4); // TODO: FPS client prop
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
    pub fn init(allocator: std.mem.Allocator, font: rl.Font, log_level: Logging.Level) Client {
        const commander = Stab.Commander(Stab.Command(CommandData)).init(allocator);
        const actioner = Stab.Actioner(SharedData).init(allocator);
        return Client{
            .log_level = log_level,
            .font = font,
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
        const stats = std.fmt.allocPrintZ(allocator,
            "Client:\n" ++
            "    username: {s}\n" ++
            "    id: {s}\n" ++
            "    server_address: {s}\n" ++
            "    client_address: {s}",
            .{self.username, self.id, self.server_addr_str, self.client_addr_str}
        ) catch |err| {
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

    pub fn sendRequestToServer(self: @This(), request: Protocol) void {
        // Open a sterm to the server
        const req_stream = std.net.tcpConnectToAddress(self.server_addr) catch |err| {
            std.log.err("client::sendRequestToServer: {any}", .{err});
            std.posix.exit(1);
        };
        defer req_stream.close();
        // send protocol to server
        request.dump(self.log_level);
        _ = Protocol.transmit(req_stream, request);
    }
};

