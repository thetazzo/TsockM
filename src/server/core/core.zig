const std = @import("std");
const aids = @import("aids");
pub const PeerCore = @import("peer.zig");
pub const PeerRef = PeerCore.PeerRef;
pub const Peer = PeerCore.Peer;
const Protocol = aids.Protocol;
const cmn = aids.cmn;
const TextColor = aids.TextColor;
const Logging = aids.Logging;

pub const SharedData = struct {
    m: std.Thread.Mutex,
    should_exit: bool,
    peer_pool: *std.ArrayList(Peer),
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

    // TODO: peerRequestDeath server action
    pub fn peerKill(self: *@This(), server: Server, ref_id: usize) !void {
        self.m.lock();
        defer self.m.unlock();
        const peer_ = self.peer_pool.items[ref_id];
        const endp = Protocol.init(
        Protocol.Typ.REQ,
        Protocol.Act.COMM_END,
        Protocol.StatusCode.OK,
        "server",
        "server",
        "client",
        "OK",
    );
        endp.dump(server.log_level);
        _ = Protocol.transmit(peer_.stream(), endp);
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

pub const Action = struct {
    collect: struct {
        request:  *const fn (std.net.Server.Connection, *SharedData, Protocol) void,
        response: *const fn (*SharedData, Protocol) void,
        err:    *const fn () void,
    },
    transmit: struct {
        request:  *const fn (*SharedData) void,
        response: *const fn () void,
        err:    *const fn () void,
    },
};

const Actioner = struct {
    actions: std.AutoHashMap(Protocol.Act, Action), // actions that happen on `listening` thread
    patrols: std.AutoHashMap(Protocol.Act, Action), // actions that happen on `polizei` thread
    pub fn init(allocator: std.mem.Allocator) Actioner {
        const actions = std.AutoHashMap(Protocol.Act, Action).init(allocator);
        const patrols = std.AutoHashMap(Protocol.Act, Action).init(allocator);
        return Actioner{
            .actions = actions, 
            .patrols = patrols,
        };
    }
    pub fn addAction(self: *@This(), caller: Protocol.Act, act: Action) void {
        self.actions.put(caller, act) catch |err| {
            std.log.err("`core::Actioner::add`: {any}\n", .{err});
            std.posix.exit(1);
        };
    }
    pub fn getAction(self: *@This(), caller: Protocol.Act) ?Action {
        return self.actions.get(caller);
    }
    pub fn addPatrol(self: *@This(), caller: Protocol.Act, act: Action) void {
        self.patrols.put(caller, act) catch |err| {
            std.log.err("`core::Actioner::add`: {any}\n", .{err});
            std.posix.exit(1);
        };
    }
    pub fn getPatrol(self: *@This(), caller: Protocol.Act) ?Action {
        return self.patrols.get(caller);
    }
    pub fn deinit(self: *@This()) void {
        self.actions.deinit();
        self.patrols.deinit();
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
    pub fn init(
        allocator: std.mem.Allocator,
        hostname: []const u8,
        port: u16,
        log_level: Logging.Level, 
    ) Server {
        const addr = std.net.Address.resolveIp(hostname, port) catch |err| {
            std.log.err("`server::init::addr`: {any}\n", .{err});
            std.posix.exit(1);
        };
        const actioner = Actioner.init(allocator);
        return Server {
            .hostname = hostname,
            .port = port,
            .log_level = log_level,
            .address = addr,
            .address_str = cmn.address_as_str(addr),
            .Actioner = actioner,
        };
    }
    pub fn start(self: *@This()) void {
        const net_server = self.address.listen(.{
            .reuse_address = true,
        }) catch |err| {
            std.log.err("`server::start::net_server`: {any}\n", .{err});
            std.posix.exit(1);
        };
        std.debug.print("Server running on `" ++ TextColor.paint_green("{s}") ++ "`\n", .{self.address_str});
        const start_time = std.time.Instant.now() catch |err| {
            std.log.err("`server::init::start_time`: {any}\n", .{err});
            std.posix.exit(1);
        };
        self.net_server = net_server;
        self.start_time = start_time;
    }
    pub fn launch_listener(self: @This()) void {
        _ = self;
        std.log.err("not implemented", .{});
        std.posix.exit(1);
    }
    pub fn deinit(self: *@This()) void {
        self.net_server.deinit();
        self.Actioner.deinit();
    }
};
