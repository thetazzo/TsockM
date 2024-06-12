const std = @import("std");
const aids = @import("aids");
const actioner_lib = @import("actioner.zig");
const commander_lib = @import("commander.zig");
const Actioner = actioner_lib.Actioner;
pub const Action = actioner_lib.Action;
pub const ParseAct = actioner_lib.parseAct;
pub const Act = actioner_lib.Act;
pub const Commander = commander_lib.Commander;
pub const Command = commander_lib.Command;
pub const PeerCore = @import("peer.zig");
pub const PeerRef = PeerCore.PeerRef;
pub const Peer = PeerCore.Peer;
const Protocol = aids.Protocol;
const cmn = aids.cmn;
const TextColor = aids.TextColor;
const Logging = aids.Logging;

pub const SharedData = struct {
    m: std.Thread.Mutex = undefined,
    should_exit: bool = undefined,
    peer_pool: *std.ArrayList(Peer) = undefined,
    server: Server,

    pub fn setShouldExit(self: *@This(), should: bool) void {
        self.m.lock();
        defer self.m.unlock();
        self.should_exit = should;
    }

    pub fn clearPeerPool(self: *@This()) void {
        self.m.lock();
        defer self.m.unlock();
        self.peer_pool.clearAndFree();
    }

    pub fn peerRemove(self: *@This(), pid: usize) void {
        self.m.lock();
        defer self.m.unlock();
        _ = self.peer_pool.orderedRemove(pid);
    }

    pub fn removePeerFromPool(self: *@This(), peer_ref: PeerRef) void {
        self.m.lock();
        defer self.m.unlock();
        self.peer_pool.items[peer_ref.ref_id].alive = false;
        _ = self.peer_pool.orderedRemove(peer_ref.ref_id);
    }

    pub fn peerPoolAppend(self: *@This(), peer: Peer) !void {
        self.m.lock();
        defer self.m.unlock();
        try self.peer_pool.append(peer);
    }
};

pub const Server = struct {
    hostname: []const u8,
    port: u16,
    address: std.net.Address,
    log_level: Logging.Level, 
    address_str: []const u8,
    start_time: std.time.Instant = undefined,
    net_server: std.net.Server = undefined,
    Actioner: Actioner,
    Commander: Commander,
    __version__: []const u8,
    pub fn init(
        allocator: std.mem.Allocator,
        hostname: []const u8,
        port: u16,
        log_level: Logging.Level, 
        __version__: []const u8,
    ) Server {
        const addr = std.net.Address.resolveIp(hostname, port) catch |err| {
            std.log.err("`server::init::addr`: {any}\n", .{err});
            std.posix.exit(1);
        };
        const actioner = Actioner.init(allocator);
        const commander = Commander.init(allocator);
        return Server {
            .hostname = hostname,
            .port = port,
            .log_level = log_level,
            .address = addr,
            .address_str = cmn.address_as_str(addr),
            .Actioner = actioner,
            .Commander = commander,
            .__version__ = __version__,
        };
    }
    pub fn printServerRunning(self: @This()) void {
        std.debug.print(
            "Server running on `" ++ aids.TextColor.paint_green("{s}") ++ "` ",
            .{self.address_str},
        );
        switch (self.log_level) {
            .DEV => {
                std.debug.print(TextColor.paint_hex("#ffa500", "(DEV)"), .{});
            },
            .COMPACT => {
                std.debug.print(TextColor.paint_hex("#ffa500", "(COMPACT)"), .{});
            },
            .SILENT => {
                std.debug.print(TextColor.paint_hex("#ffa500", "(MUTED)"), .{});
            },
        }
        std.debug.print("\n", .{});
    }
    pub fn start(self: *@This()) void {
        const net_server = self.address.listen(.{
            .reuse_address = true,
        }) catch |err| {
            std.log.err("`server::start::net_server`: {any}\n", .{err});
            std.posix.exit(1);
        };
        aids.TextColor.clearScreen();
        self.printServerRunning();
        const start_time = std.time.Instant.now() catch |err| {
            std.log.err("`server::init::start_time`: {any}\n", .{err});
            std.posix.exit(1);
        };
        self.net_server = net_server;
        self.start_time = start_time;
    }
    pub fn deinit(self: *@This()) void {
        self.net_server.deinit();
        self.Actioner.deinit();
        self.Commander.deinit();
    }
};
