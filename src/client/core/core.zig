const std = @import("std");
const ui = @import("../ui/ui.zig");
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
};

pub const Client = struct {
    id: []const u8 = undefined,
    username: []const u8 = undefined,
    Commander: Stab.Commander(Stab.Command(SharedData)),
    Actioner: Stab.Actioner(Stab.Action(SharedData)),
    log_level: Logging.Level,
    // Should the client be it's own server ?
    stream: std.net.Stream = undefined,
    server_addr: std.net.Address = undefined,
    server_addr_str: []const u8 = "404: not found",
    client_addr: std.net.Address = undefined,
    client_addr_str: []const u8 = "404: not found",
    pub fn init(allocator: std.mem.Allocator, log_level: Logging.Level) Client {
        const commander = Stab.Commander(Stab.Command(SharedData)).init(allocator);
        const actioner = Stab.Actioner(Stab.Action(SharedData)).init(allocator);
        return Client{
            .log_level = log_level,
            .Commander = commander,
            .Actioner = actioner,
        };
    }
    pub fn deinit(self: *@This()) void {
        self.Commander.deinit();
        self.Actioner.deinit();
    }
    pub fn setUsername(self: *@This(), username: []const u8) void {
        self.username = username;
    }
    pub fn setID(self: *@This(), id: []const u8) void {
        self.id = id;
    }
    pub fn connect(self: *@This(), allocator: std.mem.Allocator, hostname: []const u8, port: u16) void {
        const addr = std.net.Address.resolveIp(hostname, port) catch |err| {
            std.log.err("client::connect: {any}", .{err});
            std.posix.exit(1);
        };
        std.debug.print("Requesting connection to `{s}:{d}`\n", .{hostname, port});
        const stream = std.net.tcpConnectToAddress(addr) catch |err| {
            std.log.err("client::connect: {any}", .{err});
            std.posix.exit(1);
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
            self.username,
        );
        reqp.dump(self.log_level);
        _ = Protocol.transmit(stream, reqp);

        const resp = Protocol.collect(allocator, stream) catch |err| {
            std.log.err("client::connect: {any}", .{err});
            std.posix.exit(1);
        };
        resp.dump(self.log_level);

        if (resp.status_code == Protocol.StatusCode.OK) {
            var peer_spl = std.mem.split(u8, resp.body, "|");
            const id = peer_spl.next().?;
            const username_ = peer_spl.next().?;
            self.setUsername(username_);
            self.setID(id);
            self.stream = stream;
            self.server_addr = addr;
            self.server_addr_str = dst_addr;
            self.client_addr_str = resp.dst;
        } else {
            std.log.err("server error when creating client", .{});
            std.posix.exit(1);
        }
    }

    pub fn asStr(self: @This(), allocator: std.mem.Allocator) []const u8 {
        const stats = std.fmt.allocPrint(allocator,
            "username: {s}\n" ++
            "id: {s}\n" ++
            "server_address: {s}\n" ++
            "client_address: {s}\n",
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

