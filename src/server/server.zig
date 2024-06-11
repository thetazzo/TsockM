const std = @import("std");
const aids = @import("aids");
const core = @import("core/core.zig");
const COMM_ACTION = @import("actions/comm-action.zig").ACTION;
const COMM_END_ACTION = @import("actions/comm-end-action.zig").ACTION;
const MSG_ACTION = @import("actions/msg-action.zig").ACTION;
const GET_PEER_ACTION = @import("actions/get-peer-action.zig").ACTION;
const NTFY_KILL_ACTION = @import("actions/ntfy-kill-action.zig").ACTION;
const BAD_REQUEST_ACTION = @import("actions/bad-request-action.zig").ACTION;
const Server = core.Server;
const Peer = core.Peer;
const PeerRef = core.PeerRef;
const SharedData = core.SharedData;
const Protocol = aids.Protocol;
const cmn = aids.cmn;
const TextColor = aids.TextColor;
const Logging = aids.Logging;
const net = std.net;
const mem = std.mem;
const print = std.debug.print;

const str_allocator = std.heap.page_allocator;

pub fn peerRefFromUsername(peer_pool: *std.ArrayList(Peer), username: []const u8) ?PeerRef {
    // O(n)
    for (peer_pool.items, 0..) |peer, i| {
        if (mem.eql(u8, peer.username, username)) {
            return .{ .peer = peer, .ref_id = i };
        }
    }
    return null;
}

/// TODO: convert to server action
fn messageBroadcast(sd: *SharedData, sender_id: []const u8, msg: []const u8,) void {
    _ = sd;
    _ = sender_id;
    _ = msg;
    std.log.warn("`messageBroadcast` is depricated", .{});
}

/// TODO: convert to server action
fn connectionAccept( sd: *SharedData, conn: net.Server.Connection, server_addr: []const u8, protocol: Protocol,) !void {
    _ = sd;
    _ = conn;
    _ = server_addr;
    _ = protocol;
    std.log.warn("`connectionAccept` is depricated", .{});
}

/// TODO: convert to server action
fn connectionTerminate(sd: *SharedData, protocol: Protocol) !void {
    _ = sd;
    _ = protocol;
    std.log.warn("`connectionTerminate` is depricated", .{});
}

/// I am thread
fn listener(
    sd: *SharedData,
) !void {
    while (!sd.should_exit) {
        const conn = try sd.server.net_server.accept();

        const stream = conn.stream;

        var buf: [256]u8 = undefined;
        _ = try stream.read(&buf);
        const recv = mem.sliceTo(&buf, 170);

        // Handle communication request
        var protocol = Protocol.protocolFromStr(recv); // parse protocol from recieved bytes
        protocol.dump(sd.server.log_level);

        const opt_action = sd.server.Actioner.get(protocol.action);
        if (opt_action) |act| {
            switch (protocol.type) {
                .REQ => act.collect.request(conn, sd, protocol),
                .RES => act.collect.response(sd, protocol),
                .ERR => act.collect.err(),
                else => {
                    std.log.err("`therad::listener`: unknown protocol type!", .{});
                    unreachable;
                }
            }
        }
    }
    print("Ending `listener`\n", .{});
}

fn printUsage() void {
    print("COMMANDS:\n", .{});
    print("    * :c .............................. clear screen\n", .{});
    print("    * :info ........................... print server statiistics\n", .{});
    print("    * :exit ........................... terminate server\n", .{});
    print("    * :help ........................... print server commands\n", .{});
    print("    * :clean-pool ..................... removes dead peers\n", .{});
    print("    * :list | :ls  .................... list all active peers\n", .{});
    print("    * :ping <peer_id> | all ........... ping peer/s and update its/their life status\n", .{});
    print("    * :kill <peer_id> | all ........... kill peer/s\n", .{});
}

fn extractCommandValue(cs: []const u8, cmd: []const u8) []const u8 {
    var splits = mem.split(u8, cs, cmd);
    _ = splits.next().?; // the `:msg` part
    const val = mem.trimLeft(u8, splits.next().?, " \n");
    if (val.len <= 0) {
        std.log.err("missing action value", .{});
        printUsage();
    }
    return val;
}

// TODO: convert to server action
pub fn peerPoolClean(sd: *SharedData) void {
    var pp_len: usize = sd.peer_pool.items.len;
    while (pp_len > 0) {
        pp_len -= 1;
        const p = sd.peer_pool.items[pp_len];
        if (p.alive == false) {
            _ = sd.peerRemove(pp_len);
        }
    }
}

/// i am a thread
fn commander(
    sd: *SharedData,
    server_cmds: *std.StringHashMap(Command),
) !void {
    while (!sd.should_exit) {
        // read for command
        var buf: [256]u8 = undefined;
        const stdin = std.io.getStdIn().reader();
        if (try stdin.readUntilDelimiterOrEof(buf[0..], '\n')) |user_input| {
            // Handle different commands
            var splits = mem.splitScalar(u8, user_input, ' ');
            if (splits.next()) |ui| {
                if (server_cmds.get(ui)) |cmd| {
                    cmd(user_input, sd);
                } else {
                    print("Unknown command: `{s}`\n", .{user_input});
                    printUsage();
                }
            }
        } else {
            std.log.err("something went wrong when reading stdin!", .{});
            std.posix.exit(1);
        }
    }
    print("Thread `run_cmd` finished\n", .{});
}

/// this is a thread
fn polizei(sd: *SharedData) !void {
    var start_t = try std.time.Instant.now();
    var lock = false;
    while (!sd.should_exit) {
        const now_t = try std.time.Instant.now();
        const dt  = now_t.since(start_t) / std.time.ns_per_ms;
        if (dt == 2000 and !lock) {
            if (sd.server.Actioner.get(Protocol.Act.COMM)) |act| {
                act.transmit.request(Protocol.TransmitionMode.BROADCAST, sd);
            }
            lock = true;
        }
        if (dt == 3000 and lock) {
            if (sd.server.Actioner.get(Protocol.Act.NTFY_KILL)) |act| {
                act.transmit.request(Protocol.TransmitionMode.BROADCAST, sd);
            }
            lock = false;
        }
        if (dt == 4000 and !lock) {
            peerPoolClean(sd);
            lock = false;
            start_t = try std.time.Instant.now();
        }
    }
}

fn pingAllPeers(sd: *SharedData) void {
    _ = sd;
    std.log.warn("`pingAllPeers` is depricated", .{});
}

// TODO: convert to server action
fn peerNtfyDeath(sd: *SharedData, server: Server) void {
    _ = server;
    for (sd.peer_pool.items) |peer| {
        if (peer.alive == false) {
            // TODO: peer_broadcast_death
            for (sd.peer_pool.items) |ap| {
                if (!mem.eql(u8, ap.id, peer.id)) {
                    const ntfy = Protocol.init(
                    Protocol.Typ.REQ,
                    Protocol.Act.NTFY_KILL,
                    Protocol.StatusCode.OK,
                    "server",
                    "server",
                    "client",
                    peer.id,
                );
                    _ = Protocol.transmit(ap.stream(), ntfy);
                }
            }
        }
    }
}

const Command = *const fn ([]const u8, *SharedData) void;

const ServerCommand = struct {
    pub fn exitServer(cmd: []const u8, sd: *SharedData) void {
        _ = cmd;
        _ = sd;
        print("Exiting server ...\n", .{});
        std.posix.exit(0);
    }
    pub fn printServerStats(cmd: []const u8, sd: *SharedData) void {
        _ = cmd;
        const now = std.time.Instant.now() catch |err| {
            std.log.err("`printServerStats`: {any}", .{err});
            std.posix.exit(1);
        };
        const dt = now.since(sd.server.start_time) / std.time.ns_per_ms / 1000;
        print("==================================================\n", .{});
        print("Server status\n", .{});
        print("--------------------------------------------------\n", .{});
        print("peers connected: {d}\n", .{sd.peer_pool.items.len});
        print("uptime: {d:.3}s\n", .{dt});
        print("address: {s}\n", .{ sd.server.address_str });
        print("==================================================\n", .{});
    }
    pub fn listActivePeers(cmd: []const u8, sd: *SharedData) void {
        _ = cmd;
        if (sd.peer_pool.items.len == 0) {
            print("Peer list: []\n", .{});
        } else {
            print("Peer list ({d}):\n", .{sd.peer_pool.items.len});
            for (sd.peer_pool.items[0..]) |peer| {
                peer.dump();
            }
        }
    }
    pub fn killPeers(cmd: []const u8, sd: *SharedData) void {
        var split = mem.splitBackwardsScalar(u8, cmd, ' ');
        if (split.next()) |arg| {
            if (mem.eql(u8, arg, cmd)) {
                std.log.err("missing argument", .{});
                printUsage();
                return;
            }
            if (mem.eql(u8, arg, "all")) {
                for (sd.peer_pool.items[0..]) |peer| {
                    const endp = Protocol.init(
                    Protocol.Typ.REQ,
                    Protocol.Act.COMM_END,
                    Protocol.StatusCode.OK,
                    "server",
                    sd.server.address_str,
                    peer.commAddressAsStr(),
                    "OK",
                );
                    endp.dump(sd.server.log_level);
                    _ = Protocol.transmit(peer.stream(), endp);
                }
                sd.clearPeerPool();
            } else {
                const opt_peer_ref = core.PeerCore.peerRefFromId(sd.peer_pool, arg);
                if (opt_peer_ref) |peer_ref| {
                    try sd.peerKill(sd.server, peer_ref.ref_id);
                }
            }
        }
    }
    fn ping(cmd: []const u8, sd: *SharedData) void {
        var split = mem.splitBackwardsScalar(u8, cmd, ' ');
        if (split.next()) |arg| {
            if (mem.eql(u8, arg, cmd)) {
                std.log.err("missing argument", .{});
                printUsage();
                return;
            }
            if (mem.eql(u8, arg, "all")) {
                for (sd.peer_pool.items, 0..) |peer, pid| {
                    const reqp = Protocol{
                        .type = Protocol.Typ.REQ, // type
                        .action = Protocol.Act.COMM, // action
                        .status_code = Protocol.StatusCode.OK, // status_code
                        .sender_id = "server", // sender_id
                        .src = sd.server.address_str, // src_address
                        .dst = peer.commAddressAsStr(), // dst address
                        .body = "check?", // body
                    };
                    reqp.dump(Logging.Level.DEV);
                    // TODO: I don't know why but i must send 2 requests to determine the status of the stream
                    _ = Protocol.transmit(peer.stream(), reqp);
                    const status = Protocol.transmit(peer.stream(), reqp);
                    if (status == 1) {
                        // TODO: Put htis into sd ??
                        sd.peer_pool.items[pid].alive = false;
                    } 
                }
            } else {
                var found: bool = false;
                for (sd.peer_pool.items, 0..) |peer, pid| {
                    if (mem.eql(u8, peer.id, arg)) {
                        const reqp = Protocol{
                            .type = Protocol.Typ.REQ, // type
                            .action = Protocol.Act.COMM, // action
                            .status_code = Protocol.StatusCode.OK, // status_code
                            .sender_id = "server", // sender_id
                            .src = sd.server.address_str, // src_address
                            .dst = peer.commAddressAsStr(), // dst address
                            .body = "check?", // body
                        };
                        reqp.dump(Logging.Level.DEV);
                        // TODO: I don't know why but i must send 2 requests to determine the status of the stream
                        _ = Protocol.transmit(peer.stream(), reqp);
                        const status = Protocol.transmit(peer.stream(), reqp);
                        if (status == 1) {
                            // TODO: Put htis into sd ??
                            sd.peer_pool.items[pid].alive = false;
                        } 
                        found = true;
                    }
                }
                if (!found) {
                    print("Peer with id `{s}` was not found!\n", .{arg});
                }
            }
        }
    }
    pub fn clearScreen(cmd: []const u8, sd: *SharedData) void {
        _ = cmd;
        cmn.screenClear() catch |err| {
            print("`clearScreen`: {any}\n", .{err});
        };
        print("Server running on `" ++ TextColor.paint_green("{s}") ++ "`\n", .{sd.server.address_str});
    }
    pub fn cleanPool(cmd: []const u8, sd: *SharedData) void {
        _ = cmd;
        peerPoolClean(sd);
    }
    pub fn printProgramUsage(cmd: []const u8, sd: *SharedData) void {
        _ = cmd;
        _ = sd;
        printUsage();
    }
};

pub fn start(hostname: []const u8, port: u16, log_level: Logging.Level) !void {

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_allocator = gpa.allocator();

    var server = Server.init(gpa_allocator, hostname, port, log_level);
    defer server.deinit();

    server.Actioner.add(Protocol.Act.COMM, COMM_ACTION);
    server.Actioner.add(Protocol.Act.COMM_END, COMM_END_ACTION);
    server.Actioner.add(Protocol.Act.MSG, MSG_ACTION);
    server.Actioner.add(Protocol.Act.GET_PEER, GET_PEER_ACTION);
    server.Actioner.add(Protocol.Act.NTFY_KILL, NTFY_KILL_ACTION);
    server.Actioner.add(Protocol.Act.NONE, BAD_REQUEST_ACTION);

    var server_cmds = std.StringHashMap(Command).init(gpa_allocator);
    errdefer server_cmds.deinit();
    defer server_cmds.deinit();

    _ = try server_cmds.put(":exit"      , ServerCommand.exitServer);
    _ = try server_cmds.put(":info"      , ServerCommand.printServerStats);
    _ = try server_cmds.put(":list"      , ServerCommand.listActivePeers);
    _ = try server_cmds.put(":ls"        , ServerCommand.listActivePeers);
    _ = try server_cmds.put(":kill"      , ServerCommand.killPeers);
    _ = try server_cmds.put(":ping"      , ServerCommand.ping);
    _ = try server_cmds.put(":c"         , ServerCommand.clearScreen);
    _ = try server_cmds.put(":clean-pool", ServerCommand.cleanPool);
    _ = try server_cmds.put(":help"      , ServerCommand.printProgramUsage);

    var peer_pool = std.ArrayList(Peer).init(gpa_allocator);
    defer peer_pool.deinit();

    try cmn.screenClear();
    server.start();

    var thread_pool: [3]std.Thread = undefined;
    var sd = SharedData{
        .m = std.Thread.Mutex{},
        .should_exit = false,
        .peer_pool = &peer_pool,
        .server = server,
    };
    {
        thread_pool[0] = try std.Thread.spawn(.{}, listener, .{ &sd });
        thread_pool[1] = try std.Thread.spawn(.{}, commander, .{ &sd, &server_cmds });
        thread_pool[2] = try std.Thread.spawn(.{}, polizei, .{ &sd });
    }
    defer for(thread_pool) |thr| thr.join();
}
