const std = @import("std");
const ptc = @import("ptc");
const cmn = @import("cmn");
const TextColor = @import("text_color");
const Peer = @import("peer.zig");
const net = std.net;
const mem = std.mem;
const print = std.debug.print;

const str_allocator = std.heap.page_allocator;

const LOG_LEVEL = ptc.LogLevel.DEV;

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

pub fn peerRefFromUsername(peer_pool: *std.ArrayList(Peer), un: []const u8) ?PeerRef {
    // O(n)
    for (peer_pool.items, 0..) |peer, i| {
        if (mem.eql(u8, peer.username, un)) {
            return .{ .peer = peer, .ref_id = i };
        }
    }
    return null;
}

///====================================================================================
///
///====================================================================================
fn server_start(address: []const u8, port: u16) !net.Server {
    const addr = try net.Address.resolveIp(address, port);
    print("Server running on `" ++ TextColor.paint_green("{s}:{d}") ++ "`\n", .{address, port});
    return addr.listen(.{
        .reuse_address = true,
    });
}

///====================================================================================
/// Send message to all connected peers
///     - Server action
///====================================================================================
fn message_broadcast(
    sd: *SharedData,
    sender_id: []const u8,
    msg: []const u8,
) void {
    const opt_peer_ref = peerRefFromId(sd.peer_pool, sender_id);
    if (opt_peer_ref) |peer_ref| {
        for (sd.peer_pool.items, 0..) |peer, pid| {
            if (peer_ref.ref_id != pid and peer.alive) {
                const src_addr = peer_ref.peer.commAddressAsStr();
                const dst_addr = peer.commAddressAsStr();
                const msgp = ptc.Protocol.init(
                    ptc.Typ.RES,
                    ptc.Act.MSG,
                    ptc.StatusCode.OK,
                    sender_id,
                    src_addr,
                    dst_addr,
                    msg,
                );
                msgp.dump(LOG_LEVEL);
                _ = ptc.prot_transmit(peer.stream(), msgp);
            }
        }
    }
}

///====================================================================================
/// Establish connection between client and server
///     - Server action
///====================================================================================
fn connection_accept(
    sd: *SharedData,
    conn: net.Server.Connection,
    server_addr: []const u8,
    protocol: ptc.Protocol,
) !void {
    const addr_str = cmn.address_as_str(conn.address);
    const stream = conn.stream;

    const peer = Peer.construct(str_allocator, conn, protocol);
    const peer_str = std.fmt.allocPrint(str_allocator, "{s}|{s}", .{ peer.id, peer.username }) catch "format failed";
    try sd.peerPoolAppend(peer);
    const resp = ptc.Protocol.init(
        ptc.Typ.RES, // type
        ptc.Act.COMM, // action
        ptc.StatusCode.OK, // status code
        "server", // sender id
        server_addr, // sender address
        addr_str, // reciever address
        peer_str,
    );
    resp.dump(LOG_LEVEL);
    _ = ptc.prot_transmit(stream, resp);
}

///====================================================================================
/// Terminate connection between client and server
///     - Server action
///====================================================================================
fn connection_terminate(sd: *SharedData, protocol: ptc.Protocol) !void {
    const ref = peerRefFromId(sd.peer_pool, protocol.sender_id);
    if (ref) |peer_ref| {
        try sd.peerKill(peer_ref.ref_id);
    }
}

///====================================================================================
/// Read incomming requests from the client
///     - Server action
///====================================================================================
fn read_incomming(
    sd: *SharedData,
    server: *net.Server,
) !void {
    while (true) {
        const conn = try server.accept();
        const server_addr = cmn.address_as_str(server.listen_address);

        const stream = conn.stream;

        var buf: [256]u8 = undefined;
        _ = try stream.read(&buf);
        const recv = mem.sliceTo(&buf, 170);

        // Handle communication request
        var protocol = ptc.protocol_from_str(recv); // parse protocol from recieved bytes
        protocol.dump(LOG_LEVEL);

        const addr_str = cmn.address_as_str(conn.address);
        if (protocol.is_request()) {
            // Handle COMM request
            if (protocol.is_action(ptc.Act.COMM)) {
                try connection_accept(sd, conn, server_addr, protocol);
            } else if (protocol.is_action(ptc.Act.COMM_END)) {
                try connection_terminate(sd, protocol);
            } else if (protocol.is_action(ptc.Act.MSG)) {
                message_broadcast(sd, protocol.sender_id, protocol.body);
            } else if (protocol.is_action(ptc.Act.GET_PEER)) {
                // TODO: get peer server action
                // TODO: make a peer_find_bridge_ref
                //      - similar to peerFindRef
                //      - constructs a structure of sender peer and search peer
                const sref = peerRefFromId(sd.peer_pool, protocol.sender_id);
                const ref  = peerRefFromId(sd.peer_pool, protocol.body);
                if (sref) |sr| {
                    if (ref) |peer| {
                        const dst_addr = sr.peer.commAddressAsStr();
                        const resp = ptc.Protocol.init(
                        ptc.Typ.RES, // type
                        ptc.Act.GET_PEER, // action
                        ptc.StatusCode.OK, // status code
                        "server", // sender id
                        server_addr, // src
                        dst_addr, // dst
                        peer.peer.username, // body
                    );
                        resp.dump(LOG_LEVEL);
                        _ = ptc.prot_transmit(sr.peer.stream(), resp);
                    }
                }
            } else if (protocol.is_action(ptc.Act.NONE)) {
                // TODO: handle bad request action
                const errp = ptc.Protocol.init(
                ptc.Typ.ERR,
                protocol.action,
                ptc.StatusCode.BAD_REQUEST,
                "server",
                server_addr,
                addr_str,
                @tagName(ptc.StatusCode.BAD_REQUEST),
            );
                errp.dump(LOG_LEVEL);
                _ = ptc.prot_transmit(stream, errp);
            }
        } else if (protocol.is_response()) {
            if (protocol.is_action(ptc.Act.COMM)) {
                // TODO: handle communication response action
                const ref = peerRefFromId(sd.peer_pool, protocol.sender_id);
                if (ref) |peer| {
                    print("peer `{s}` is alive\n", .{peer.peer.username});
                } else {
                    print("Peer with id `{s}` does not exist!\n", .{protocol.sender_id});
                }
            } 
        } else if (protocol.type == ptc.Typ.NONE) {
            // TODO: handle bad request action
            const errp = ptc.Protocol.init(
            ptc.Typ.ERR,
            protocol.action,
            ptc.StatusCode.BAD_REQUEST,
            "server",
            "server",
            addr_str,
            "bad request",
        );
            errp.dump(LOG_LEVEL);
            _ = ptc.prot_transmit(stream, errp);
        } else {
            std.log.err("unreachable code", .{});
        }
    }
}

fn print_usage() void {
    print("COMMANDS:\n", .{});
    print("    * :cc ................ clear screen\n", .{});
    print("    * :list .............. list all active peers\n", .{});
    print("    * :ping all .......... ping all peers and update their life status\n", .{});
    print("    * :ping <peer_id> .... ping one peer and update its life status\n", .{});
    print("    * :kill all .......... kill all peers\n", .{});
    print("    * :kill <peer_id> .... kill one peer\n", .{});
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
    fn peerKill(self: *@This(), ref_id: usize) !void {
        self.m.lock();
        defer self.m.unlock();
        const peer_ = self.peer_pool.items[ref_id];
        const endp = ptc.Protocol.init(
            ptc.Typ.REQ,
            ptc.Act.COMM_END,
            ptc.StatusCode.OK,
            "server",
            "server",
            "client",
            "OK",
        );
        endp.dump(LOG_LEVEL);
        _ = ptc.prot_transmit(peer_.stream(), endp);
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
    pub fn pingAllPeers(self: *@This(), address_str: []const u8) void {
        self.m.lock();
        defer self.m.unlock();
        for (self.peer_pool.items, 0..) |peer_, pid| {
            const reqp = ptc.Protocol{
                .type = ptc.Typ.REQ, // type
                .action = ptc.Act.COMM, // action
                .status_code = ptc.StatusCode.OK, // status_code
                .sender_id = "server", // sender_id
                .src = address_str, // src_address
                .dst = peer_.commAddressAsStr(), // dst address
                .body = "check?", // body
            };
            reqp.dump(LOG_LEVEL);
            // TODO: I don't know why but i must send 2 requests to determine the status of the stream
            _ = ptc.prot_transmit(peer_.stream(), reqp);
            const status = ptc.prot_transmit(peer_.stream(), reqp);
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
                        const ntfy = ptc.Protocol.init(
                            ptc.Typ.REQ,
                            ptc.Act.NTFY_KILL,
                            ptc.StatusCode.OK,
                            "server",
                            "server",
                            "client",
                            peer.id,
                        );
                        _ = ptc.prot_transmit(ap.stream(), ntfy);
                    }
                }
            }
        }
    }
    pub fn peerPoolClean(self: *@This()) void {
        self.m.lock();
        defer self.m.unlock();
        var pplen: usize = self.peer_pool.items.len;
        while (pplen > 0) {
            pplen -= 1;
            const p = self.peer_pool.items[pplen];
            if (p.alive == false) {
                _ = self.peer_pool.orderedRemove(pplen);
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
fn read_cmd(
    sd: *SharedData,
    addr_str: []const u8,
    port: u16,
    start_time: std.time.Instant,
) !void {
    const address_str = std.fmt.allocPrint(str_allocator, "{s}:{d}", .{ addr_str, port }) catch "format failed";
    while (true) {
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
                const karrg = extract_command_val(user_input, ":kill");
                if (mem.eql(u8, karrg, "all")) {
                    for (sd.peer_pool.items[0..]) |peer| {
                        const endp = ptc.Protocol.init(
                            ptc.Typ.REQ,
                            ptc.Act.COMM_END,
                            ptc.StatusCode.OK,
                            "server",
                            addr_str,
                            peer.commAddressAsStr(),
                            "OK",
                        );
                        endp.dump(LOG_LEVEL);
                        _ = ptc.prot_transmit(peer.stream(), endp);
                    }
                    sd.clearPeerPool();
                } else {
                    const ref = peerRefFromId(sd.peer_pool, karrg);
                    if (ref) |peer_ref| {
                        try sd.peerKill(peer_ref.ref_id);
                    }
                }
            } else if (mem.startsWith(u8, user_input, ":ping")) {
                // TODO: ping server command
                const peer_un = extract_command_val(user_input, ":ping");
                if (mem.eql(u8, peer_un, "all")) {
                    sd.pingAllPeers(address_str);
                } else {
                    const ref = peerRefFromUsername(sd.peer_pool, peer_un);
                    if (ref) |peer_ref| {
                        const reqp = ptc.Protocol{
                            .type = ptc.Typ.REQ, // type
                            .action = ptc.Act.COMM, // action
                            .status_code = ptc.StatusCode.OK, // status_code
                            .sender_id = "server", // sender_id
                            .src = address_str, // src_address
                            .dst = peer_ref.peer.commAddressAsStr(), // dst_addres
                            .body = "check?", // body
                        };

                        reqp.dump(LOG_LEVEL);
                        // TODO: I don't know why but i must send 2 requests to determine the status of the stream
                        _ = ptc.prot_transmit(peer_ref.peer.stream(), reqp);
                        const status = ptc.prot_transmit(peer_ref.peer.stream(), reqp);
                        if (status == 1) {
                            print("peer `{s}` is dead\n", .{peer_ref.peer.username});
                            sd.removePeerFromPool(peer_ref);
                        }  
                    } else {
                        std.log.warn("Peer with username `{s}` does not exist!\n", .{peer_un});
                    }
                }
            } else if (mem.eql(u8, user_input, ":clean")) {
                // TODO: clean pool server command
                sd.peerPoolClean();
            } else if (mem.eql(u8, user_input, ":cc")) {
                // TODO: clear screen server command
                try cmn.screen_clear();
                print("Server running on `" ++ TextColor.paint_green("{s}:{d}") ++ "`\n", .{addr_str, port});
            } else if (mem.eql(u8, user_input, ":info")) {
                // TODO: print server stats server command
                const now = try std.time.Instant.now();
                const dt = now.since(start_time) / std.time.ns_per_ms / 1000;
                print("==================================================\n", .{});
                print("Server status\n", .{});
                print("--------------------------------------------------\n", .{});
                print("peers connected: {d}\n", .{sd.peer_pool.items.len});
                print("uptime: {d:.3}s\n", .{dt});
                print("address: {s}\n", .{ address_str });
                print("==================================================\n", .{});
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
    print("Thread `run_cmd` finished\n", .{});
}

///
///
///
fn polizei(sd: *SharedData) !void {
    var start_t = try std.time.Instant.now();
    var lock = false;
    while (true) {
        const now_t = try std.time.Instant.now();
        const dt  = now_t.since(start_t) / std.time.ns_per_ms;
        if (dt == 2000 and !lock) {
            sd.pingAllPeers("server");
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

pub fn start(server_addr: []const u8, server_port: u16) !void {
    try cmn.screen_clear();
    var server = try server_start(server_addr, server_port);
    errdefer server.deinit();
    defer server.deinit();
    const start_time = try std.time.Instant.now();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_allocator = gpa.allocator();

    //var messages = std.ArrayList(u8).init(gpa_allocator);
    //defer messages.deinit();

    var peer_pool = std.ArrayList(Peer).init(gpa_allocator);
    defer peer_pool.deinit();
    var sd = SharedData{
        .m = std.Thread.Mutex{},
        .should_exit = false,
        .peer_pool = &peer_pool,
    };
    {
        // TODO: Introduce thread pool
        const t1 = try std.Thread.spawn(.{}, read_incomming, .{ &sd, &server });
        defer t1.join();
        const t2 = try std.Thread.spawn(.{}, read_cmd, .{ &sd, server_addr, server_port, start_time });
        defer t2.join();
        const t3 = try std.Thread.spawn(.{}, polizei, .{ &sd });
        defer t3.join();
    }
}
