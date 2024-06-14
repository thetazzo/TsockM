const std = @import("std");
const Display = @import("../ui/display.zig");
const aids = @import("aids");
const Protocol = aids.Protocol;
const Logging = aids.Logging;

// Data to share between threads
pub const SharedData = struct {
    m: std.Thread.Mutex,
    should_exit: bool,
    messages: std.ArrayList(Display.Message),
    client: Client = undefined, // Client gets defined after the username is entered

    pub fn setShouldExit(self: *@This(), should: bool) void {
        self.m.lock();
        defer self.m.unlock();
        self.should_exit = should;
    }

    pub fn pushMessage(self: *@This(), msg: Display.Message) !void {
        self.m.lock();
        defer self.m.unlock();
        try self.messages.append(msg);
    }
};

pub const Client = struct {
    id: []const u8,
    username: []const u8,
    Commander: aids.Stab.Commander(SharedData),
    log_level: Logging.Level,
    // Should the client be it's own server ?
    stream: std.net.Stream = undefined,
    server_addr: std.net.Address = undefined,
    server_addr_str: []const u8 = undefined,
    client_addr: std.net.Address = undefined,
    client_addr_str: []const u8 = undefined,
    pub fn init(id: []const u8, username: []const u8, log_level: Logging.Level) Client {
        // acllocate commander
        return Client{
            .id = id,
            .username = username,
            .log_level = log_level,
        };
    }
    pub fn deinit(self: *@This()) void {
        self.Commander.deinit();
    }
    pub fn connect(self: *@This()) void {
        _ = self;
        std.log.err("not implemented", .{});
        std.posix.exit(1);
        // TODO: handle .server setting here
        // self.server = server
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

