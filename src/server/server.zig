const std = @import("std");
const lib = @import("lib");
const Protocol = lib.Protocol;
const cmn = lib.cmn;
const TextColor = lib.TextColor;
const Logging = lib.Logging;
const Peer = @import("peer.zig");
const net = std.net;
const mem = std.mem;
const print = std.debug.print;

const str_allocator = std.heap.page_allocator;

const PeerRef = struct {peer: Peer, ref_id: usize };

pub fn peerRefFromId(peer_pool: *std.ArrayList(Peer), id: Peer.PEER_ID) ?PeerRef {
    // O(n)
    for (peer_pool.items, 0..) |peer, i| {
        if (mem.eql(u8, peer.id, id)) {
            return .{ .peer = peer, .ref_id = i };
        }
    }
    return null;
}

pub fn peerRefFromUsername(peer_pool: *std.ArrayList(Peer), username: []const u8) ?PeerRef {
    // O(n)
    for (peer_pool.items, 0..) |peer, i| {
        if (mem.eql(u8, peer.username, username)) {
            return .{ .peer = peer, .ref_id = i };
        }
    }
    return null;
}

///====================================================================================
///
///====================================================================================
const Server = struct {
    hostname: []const u8,
    port: u16,
    log_level: Logging.Level, 
    start_time: std.time.Instant,
    net_server: net.Server,
};

fn serverStart(hostname: []const u8, port: u16, log_level: Logging.Level) !Server {
    const addr = try net.Address.resolveIp(hostname, port);
    print("Server running on `" ++ TextColor.paint_green("{s}:{d}") ++ "`\n", .{hostname, port});
    const start_time = try std.time.Instant.now();
    return Server{
        .hostname = hostname,
        .port = port,
        .start_time = start_time,
        .log_level = log_level,
        // TODO: catchh error
        .net_server = try addr.listen(.{
            .reuse_address = true,
        })
    };
}

///====================================================================================
/// Send message to all connected peers
///     - Server action
///====================================================================================
fn messageBroadcast(
    sd: *SharedData,
    server: *Server,
    sender_id: []const u8,
    msg: []const u8,
) void {
    const opt_peer_ref = peerRefFromId(sd.peer_pool, sender_id);
    if (opt_peer_ref) |peer_ref| {
        for (sd.peer_pool.items, 0..) |peer, pid| {
            if (peer_ref.ref_id != pid and peer.alive) {
                const src_addr = peer_ref.peer.commAddressAsStr();
                const dst_addr = peer.commAddressAsStr();
                const msgp = Protocol.init(
                    Protocol.Typ.RES,
                    Protocol.Act.MSG,
                    Protocol.StatusCode.OK,
                    sender_id,
                    src_addr,
                    dst_addr,
                    msg,
                );
                msgp.dump(server.*.log_level);
                _ = Protocol.transmit(peer.stream(), msgp);
            }
        }
    }
}

///====================================================================================
/// Establish connection between client and server
///     - Server action
///====================================================================================
fn connectionAccept(
    sd: *SharedData,
    server: *Server,
    conn: net.Server.Connection,
    server_addr: []const u8,
    protocol: Protocol,
) !void {
    const addr_str = cmn.address_as_str(conn.address);
    const stream = conn.stream;

    const peer = Peer.construct(str_allocator, conn, protocol);
    const peer_str = std.fmt.allocPrint(str_allocator, "{s}|{s}", .{ peer.id, peer.username }) catch "format failed";
    try sd.peerPoolAppend(peer);
    const resp = Protocol.init(
        Protocol.Typ.RES, // type
        Protocol.Act.COMM, // action
        Protocol.StatusCode.OK, // status code
        "server", // sender id
        server_addr, // sender address
        addr_str, // reciever address
        peer_str,
    );
    resp.dump(server.log_level);
    _ = Protocol.transmit(stream, resp);
}

///====================================================================================
/// Terminate connection between client and server
///     - Server action
///====================================================================================
fn connectionTerminate(sd: *SharedData, server: *Server, protocol: Protocol) !void {
    const opt_peer_ref = peerRefFromId(sd.peer_pool, protocol.sender_id);
    if (opt_peer_ref) |peer_ref| {
        try sd.peerKill(server.*, peer_ref.ref_id);
    }
}

///====================================================================================
/// Read incomming requests from the client
///     - Server action
///====================================================================================
fn readIncomming(
    sd: *SharedData,
    server: *Server,
) !void {
    while (!sd.should_exit) {
        const conn = try server.net_server.accept();
        const server_addr = cmn.address_as_str(server.net_server.listen_address);

        const stream = conn.stream;

        var buf: [256]u8 = undefined;
        _ = try stream.read(&buf);
        const recv = mem.sliceTo(&buf, 170);

        // Handle communication request
        var protocol = Protocol.protocolFromStr(recv); // parse protocol from recieved bytes
        protocol.dump(server.log_level);

        const addr_str = cmn.address_as_str(conn.address);
        if (protocol.is_request()) {
            // Handle COMM request
            if (protocol.is_action(Protocol.Act.COMM)) {
                try connectionAccept(sd, server, conn, server_addr, protocol);
            } else if (protocol.is_action(Protocol.Act.COMM_END)) {
                try connectionTerminate(sd, server, protocol);
            } else if (protocol.is_action(Protocol.Act.MSG)) {
                messageBroadcast(sd, server, protocol.sender_id, protocol.body);
            } else if (protocol.is_action(Protocol.Act.GET_PEER)) {
                // TODO: get peer server action
                // TODO: make a peer_find_bridge_ref
                //      - similar to peerFindRef
                //      - constructs a structure of sender peer and search peer
                const opt_server_peer_ref = peerRefFromId(sd.peer_pool, protocol.sender_id);
                const opt_peer_ref  = peerRefFromId(sd.peer_pool, protocol.body);
                if (opt_server_peer_ref) |server_peer_ref| {
                    if (opt_peer_ref) |peer_ref| {
                        const dst_addr = server_peer_ref.peer.commAddressAsStr();
                        const resp = Protocol.init(
                        Protocol.Typ.RES, // type
                        Protocol.Act.GET_PEER, // action
                        Protocol.StatusCode.OK, // status code
                        "server", // sender id
                        server_addr, // src
                        dst_addr, // dst
                        peer_ref.peer.username, // body
                    );
                        resp.dump(server.log_level);
                        _ = Protocol.transmit(server_peer_ref.peer.stream(), resp);
                    }
                }
            } else if (protocol.is_action(Protocol.Act.NONE)) {
                // TODO: handle bad request action
                const errp = Protocol.init(
                Protocol.Typ.ERR,
                protocol.action,
                Protocol.StatusCode.BAD_REQUEST,
                "server",
                server_addr,
                addr_str,
                @tagName(Protocol.StatusCode.BAD_REQUEST),
            );
                errp.dump(server.log_level);
                _ = Protocol.transmit(stream, errp);
            }
        } else if (protocol.is_response()) {
            if (protocol.is_action(Protocol.Act.COMM)) {
                // TODO: handle communication response action
                const opt_peer_ref = peerRefFromId(sd.peer_pool, protocol.sender_id);
                if (opt_peer_ref) |peer_ref| {
                    print("peer `{s}` is alive\n", .{peer_ref.peer.username});
                } else {
                    print("Peer with id `{s}` does not exist!\n", .{protocol.sender_id});
                }
            } 
        } else if (protocol.type == Protocol.Typ.NONE) {
            // TODO: handle bad request action
            const errp = Protocol.init(
            Protocol.Typ.ERR,
            protocol.action,
            Protocol.StatusCode.BAD_REQUEST,
            "server",
            "server",
            addr_str,
            "bad request",
        );
            errp.dump(server.log_level);
            _ = Protocol.transmit(stream, errp);
        } else {
            std.log.err("unreachable code", .{});
        }
    }
}

fn printUsage() void {
    print("COMMANDS:\n", .{});
    print("    * :cc ................ clear screen\n", .{});
    print("    * :list .............. list all active peers\n", .{});
    print("    * :ping all .......... ping all peers and update their life status\n", .{});
    print("    * :ping <peer_id> .... ping one peer and update its life status\n", .{});
    print("    * :kill all .......... kill all peers\n", .{});
    print("    * :kill <peer_id> .... kill one peer\n", .{});
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

const SharedData = struct {
    m: std.Thread.Mutex,
    should_exit: bool,
    peer_pool: *std.ArrayList(Peer),

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

    // TODO: peerRequestDeath server action
    fn peerKill(self: *@This(), server: Server, ref_id: usize) !void {
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

    // TODO: convert to a server action
    //          - only peer.alive = false should be mutex locked
    //          - introduce markPeerForDeath or straight peer remove
    pub fn pingAllPeers(self: *@This(), server: Server, address_str: []const u8) void {
        self.m.lock();
        defer self.m.unlock();
        for (self.peer_pool.items, 0..) |peer, pid| {
            const reqp = Protocol{
                .type = Protocol.Typ.REQ, // type
                .action = Protocol.Act.COMM, // action
                .status_code = Protocol.StatusCode.OK, // status_code
                .sender_id = "server", // sender_id
                .src = address_str, // src_address
                .dst = peer.commAddressAsStr(), // dst address
                .body = "check?", // body
            };
            reqp.dump(server.log_level);
            // TODO: I don't know why but i must send 2 requests to determine the status of the stream
            _ = Protocol.transmit(peer.stream(), reqp);
            const status = Protocol.transmit(peer.stream(), reqp);
            if (status == 1) {
                self.peer_pool.items[pid].alive = false;
            } 
        }
    }
    // TODO: convert this to a server action
    pub fn peerNtfyDeath(self: *@This()) void {
        self.m.lock();
        defer self.m.unlock();
        for (self.peer_pool.items) |peer| {
            if (peer.alive == false) {
                // TODO: peer_broadcast_death
                for (self.peer_pool.items) |ap| {
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
    pub fn peerPoolClean(self: *@This()) void {
        self.m.lock();
        defer self.m.unlock();
        var pp_len: usize = self.peer_pool.items.len;
        while (pp_len > 0) {
            pp_len -= 1;
            const p = self.peer_pool.items[pp_len];
            if (p.alive == false) {
                _ = self.peer_pool.orderedRemove(pp_len);
            }
        }
    }
    pub fn peerPoolAppend(self: *@This(), peer: Peer) !void {
        self.m.lock();
        defer self.m.unlock();

        try self.peer_pool.append(peer);
    }
};

// TODO: introduce ServerCommand
fn readCmd(
    sd: *SharedData,
    server: *Server,
) !void {
    const address_str = std.fmt.allocPrint(str_allocator, "{s}:{d}", .{ server.hostname, server.port }) catch "format failed";
    while (!sd.should_exit) {
        // read for command
        var buf: [256]u8 = undefined;
        const stdin = std.io.getStdIn().reader();
        if (try stdin.readUntilDelimiterOrEof(buf[0..], '\n')) |user_input| {
            // Handle different commands
            if (mem.startsWith(u8, user_input, ":exit")) {
                std.log.warn(":exit not implemented", .{});
            } else if (mem.eql(u8, user_input, ":list")) {
                // TODO: list server command
                if (sd.peer_pool.items.len == 0) {
                    print("Peer list: []\n", .{});
                } else {
                    print("Peer list ({d}):\n", .{sd.peer_pool.items.len});
                    for (sd.peer_pool.items[0..]) |peer| {
                        peer.dump();
                    }
                }
            } else if (mem.startsWith(u8, user_input, ":kill")) {
                // TODO: kill server command
                const cmd_arg = extractCommandValue(user_input, ":kill");
                if (mem.eql(u8, cmd_arg, "all")) {
                    for (sd.peer_pool.items[0..]) |peer| {
                        const endp = Protocol.init(
                            Protocol.Typ.REQ,
                            Protocol.Act.COMM_END,
                            Protocol.StatusCode.OK,
                            "server",
                            address_str,
                            peer.commAddressAsStr(),
                            "OK",
                        );
                        endp.dump(server.log_level);
                        _ = Protocol.transmit(peer.stream(), endp);
                    }
                    sd.clearPeerPool();
                } else {
                    const opt_peer_ref = peerRefFromId(sd.peer_pool, cmd_arg);
                    if (opt_peer_ref) |peer_ref| {
                        try sd.peerKill(server.*, peer_ref.ref_id);
                    }
                }
            } else if (mem.startsWith(u8, user_input, ":ping")) {
                // TODO: ping server command
                const cmd_arg = extractCommandValue(user_input, ":ping");
                if (mem.eql(u8, cmd_arg, "all")) {
                    sd.pingAllPeers(server.*, address_str);
                } else {
                    const opt_peer_ref = peerRefFromUsername(sd.peer_pool, cmd_arg);
                    if (opt_peer_ref) |peer_ref| {
                        const reqp = Protocol{
                            .type = Protocol.Typ.REQ, // type
                            .action = Protocol.Act.COMM, // action
                            .status_code = Protocol.StatusCode.OK, // status_code
                            .sender_id = "server", // sender_id
                            .src = address_str, // src_address
                            .dst = peer_ref.peer.commAddressAsStr(), // dst_addres
                            .body = "check?", // body
                        };

                        reqp.dump(server.log_level);
                        // TODO: I don't know why but i must send 2 requests to determine the status of the stream
                        _ = Protocol.transmit(peer_ref.peer.stream(), reqp);
                        const status = Protocol.transmit(peer_ref.peer.stream(), reqp);
                        if (status == 1) {
                            print("peer `{s}` is dead\n", .{peer_ref.peer.username});
                            sd.removePeerFromPool(peer_ref);
                        }  
                    } else {
                        std.log.warn("Peer with username `{s}` does not exist!\n", .{cmd_arg});
                    }
                }
            } else if (mem.eql(u8, user_input, ":clean")) {
                // TODO: clean pool server command
                sd.peerPoolClean();
            } else if (mem.eql(u8, user_input, ":cc")) {
                // TODO: clear screen server command
                try cmn.screen_clear();
                print("Server running on `" ++ TextColor.paint_green("{s}:{d}") ++ "`\n", .{server.hostname, server.port});
            } else if (mem.eql(u8, user_input, ":info")) {
                // TODO: print server stats server command
                const now = try std.time.Instant.now();
                const dt = now.since(server.start_time) / std.time.ns_per_ms / 1000;
                print("==================================================\n", .{});
                print("Server status\n", .{});
                print("--------------------------------------------------\n", .{});
                print("peers connected: {d}\n", .{sd.peer_pool.items.len});
                print("uptime: {d:.3}s\n", .{dt});
                print("address: {s}\n", .{ address_str });
                print("==================================================\n", .{});
            } else if (mem.eql(u8, user_input, ":help")) {
                printUsage();
            } else {
                print("Unknown command: `{s}`\n", .{user_input});
                printUsage();
            }
        } else {
            print("Unreachable, maybe?\n", .{});
        }
    }
    print("Thread `run_cmd` finished\n", .{});
}

///
///
///
fn polizei(sd: *SharedData, server: Server) !void {
    var start_t = try std.time.Instant.now();
    var lock = false;
    while (!sd.should_exit) {
        const now_t = try std.time.Instant.now();
        const dt  = now_t.since(start_t) / std.time.ns_per_ms;
        if (dt == 2000 and !lock) {
            sd.pingAllPeers(server, "server");
            lock = true;
        }
        if (dt == 3000 and lock) {
            sd.peerNtfyDeath();
            lock = false;
        }
        if (dt == 4000 and !lock) {
            sd.peerPoolClean();
            lock = false;
            start_t = try std.time.Instant.now();
        }
    }
}

pub fn start(hostname: []const u8, port: u16, log_level: Logging.Level) !void {
    try cmn.screen_clear();

    var server = try serverStart(hostname, port, log_level);
    errdefer server.net_server.deinit();
    defer server.net_server.deinit();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_allocator = gpa.allocator();

    //var messages = std.ArrayList(u8).init(gpa_allocator);
    //defer messages.deinit();

    var peer_pool = std.ArrayList(Peer).init(gpa_allocator);
    defer peer_pool.deinit();

    var thread_pool: [3]std.Thread = undefined;

    var sd = SharedData{
        .m = std.Thread.Mutex{},
        .should_exit = false,
        .peer_pool = &peer_pool,
    };
    {
        thread_pool[0] = try std.Thread.spawn(.{}, readIncomming, .{ &sd, &server });
        thread_pool[1] = try std.Thread.spawn(.{}, readCmd, .{ &sd, &server });
        thread_pool[2] = try std.Thread.spawn(.{}, polizei, .{ &sd, server });
        defer for(&thread_pool) |thr| thr.join();
    }
}
