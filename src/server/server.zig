const std = @import("std");
const ptc = @import("ptc");
const cmn = @import("cmn");
const sqids = @import("sqids");
const net = std.net;
const mem = std.mem;
const print = std.debug.print;

const LOG_LEVEL = ptc.LogLevel.DEV;

const SERVER_ADDRESS = "192.168.88.145";
const SERVER_PORT = 6969;

const PEER_ID = []const u8;
const str_allocator = std.heap.page_allocator;

const Peer = struct {
    conn: net.Server.Connection,
    id: PEER_ID,
    username: PEER_ID = "",
    pub fn init(conn: net.Server.Connection, id: PEER_ID) Peer {
        // TODO: check for peer.id collisions
        return Peer{
            .id = id,
            .conn = conn,
        };
    }
    pub fn stream(self: @This()) net.Stream {
        return self.conn.stream;
    }
    pub fn comm_address(self: @This()) net.Address {
        return self.conn.address;
    }
};

fn peer_dump(p: Peer) void {
    print("------------------------------------\n", .{});
    print("Peer {{\n", .{});
    print("    id: `{s}`\n", .{p.id});
    print("    username: `{s}`\n", .{p.username});
    print("    comm_addr: `{any}`\n", .{p.comm_address()});
    print("}}\n", .{});
    print("------------------------------------\n", .{});
}

fn peer_find_ref(peer_pool: *std.ArrayList(Peer), id: PEER_ID) ?struct { peer: Peer, ref_id: usize } {
    // O(n)
    var i: usize = 0;
    for (peer_pool.items[0..]) |peer| {
        if (mem.eql(u8, peer.id, id)) {
            return .{ .peer = peer, .ref_id = i };
        }
        i += 1;
    }
    return null;
}

fn peer_construct(
    conn: net.Server.Connection,
    protocol: ptc.Protocol,
) Peer {
    var rand = std.rand.DefaultPrng.init(@as(u64, @bitCast(std.time.milliTimestamp())));
    const s = sqids.Sqids.init(std.heap.page_allocator, .{ .min_length = 10 }) catch |err| {
        std.log.warn("{any}", .{err});
        std.posix.exit(1);
    };
    const id = s.encode(&.{ rand.random().int(u64), rand.random().int(u64), rand.random().int(u64) }) catch |err| {
        std.log.warn("{any}", .{err});
        std.posix.exit(1);
    };
    var peer = Peer.init(conn, id);
    const user_sig = s.encode(&.{ rand.random().int(u8), rand.random().int(u8), rand.random().int(u8) }) catch |err| {
        std.log.warn("{any}", .{err});
        std.posix.exit(1);
    };
    // DON'T EVER FORGET TO ALLOCATE MEMORY !!!!!!
    const aun = std.fmt.allocPrint(str_allocator, "{s}#{s}", .{ protocol.body, user_sig }) catch "format failed";
    peer.username = aun;
    peer_dump(peer);
    return peer;
}

fn peer_kill(ref_id: usize, peer_pool: *std.ArrayList(Peer)) !void {
    const peer = peer_pool.items[ref_id];
    const endp = ptc.Protocol.init(
        ptc.Typ.RES,
        ptc.Act.COMM_END,
        ptc.StatusCode.OK,
        "server",
        "server",
        "client",
        "OK",
    );
    endp.dump(LOG_LEVEL);
    _ = ptc.prot_transmit(peer.stream(), endp);
    _ = peer_pool.orderedRemove(ref_id);
}

fn server_start(address: []const u8, port: u16) !net.Server {
    const lh = try net.Address.resolveIp(address, port);
    print("Server running on `{s}:{d}`\n", .{ address, port });
    return lh.listen(.{
        // TODO this flag needs to be set for bettter server performance
        .reuse_address = true,
    });
}

fn message_broadcast(
    peer_pool: *std.ArrayList(Peer),
    sender_id: []const u8,
    msg: []const u8,
) !void {
    var pind: usize = 0;
    const peer_ref = peer_find_ref(peer_pool, sender_id);
    if (peer_ref) |pf| {
        for (peer_pool.items[0..]) |peer| {
            if (pf.ref_id != pind) {
                const src_addr = cmn.address_as_str(pf.peer.comm_address());
                const dst_addr = cmn.address_as_str(peer.comm_address());
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
            pind += 1;
        }
    }
}

fn read_incomming(
    peer_pool: *std.ArrayList(Peer),
    conn: net.Server.Connection,
) !void {
    const stream = conn.stream;

    var buf: [256]u8 = undefined;
    _ = try stream.read(&buf);
    const recv = mem.sliceTo(&buf, 170);

    // Handle communication request
    var protocol = ptc.protocol_from_str(recv); // parse protocol from recieved bytes
    protocol.dump(LOG_LEVEL);

    const addr_str = cmn.address_as_str(conn.address);
    if (protocol.is_request()) {
        if (protocol.is_action(ptc.Act.COMM)) {
            const peer = peer_construct(conn, protocol);
            const peer_str = std.fmt.allocPrint(str_allocator, "{s}|{s}", .{ peer.id, peer.username }) catch "format failed";
            try peer_pool.append(peer);
            const resp = ptc.Protocol.init(
                ptc.Typ.RES,
                ptc.Act.COMM,
                ptc.StatusCode.OK,
                "server",
                "server",
                addr_str,
                peer_str,
            );
            resp.dump(LOG_LEVEL);
            _ = ptc.prot_transmit(stream, resp);
        } else if (protocol.is_action(ptc.Act.COMM_END)) {
            const peer_ref = peer_find_ref(peer_pool, protocol.sender_id);
            if (peer_ref) |pf| {
                try peer_kill(pf.ref_id, peer_pool);
            }
        } else if (protocol.is_action(ptc.Act.MSG)) {
            try message_broadcast(peer_pool, protocol.sender_id, protocol.body);
        } else if (protocol.is_action(ptc.Act.GET_PEER)) {
            // TODO: make a peer_find_bridge_ref
            //      - similar to peer_find_ref
            //      - constructs a structure of sender peer and search peer
            const sref = peer_find_ref(peer_pool, protocol.sender_id);
            const ref = peer_find_ref(peer_pool, protocol.body);
            if (sref) |sr| {
                if (ref) |pr| {
                    const dst_addr = cmn.address_as_str(sr.peer.comm_address());
                    const resp = ptc.Protocol.init(
                        ptc.Typ.RES, // type
                        ptc.Act.GET_PEER, // action
                        ptc.StatusCode.OK, // status code
                        "server", // sender id
                        "server", // src
                        dst_addr, // dst
                        pr.peer.username, // body
                    );
                    resp.dump(LOG_LEVEL);
                    _ = ptc.prot_transmit(sr.peer.stream(), resp);
                }
            }
        } else if (protocol.is_action(ptc.Act.NONE)) {
            const errp = ptc.Protocol.init(
                ptc.Typ.ERR,
                protocol.action,
                ptc.StatusCode.BAD_REQUEST,
                "server",
                "server",
                addr_str,
                @tagName(ptc.StatusCode.BAD_REQUEST),
            );
            errp.dump(LOG_LEVEL);
            _ = ptc.prot_transmit(stream, errp);
        }
    } else if (protocol.is_response()) {
        if (protocol.is_action(ptc.Act.COMM)) {}
    } else if (protocol.type == ptc.Typ.NONE) {
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

fn server_core(
    server: *net.Server,
    peer_pool: *std.ArrayList(Peer),
) !void {
    while (true) {
        const conn = try server.accept();
        try read_incomming(peer_pool, conn);
    }
    print("Thread `server_core` finished\n", .{});
}

fn print_usage() void {
    print("COMMANDS:\n", .{});
    print("    * :cc ................ clear screen\n", .{});
    print("    * :list .............. list all active peers\n", .{});
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

fn read_cmd(
    peer_pool: *std.ArrayList(Peer),
) !void {
    while (true) {
        // read for command
        var buf: [256]u8 = undefined;
        const stdin = std.io.getStdIn().reader();
        if (try stdin.readUntilDelimiterOrEof(buf[0..], '\n')) |user_input| {
            // Handle different commands
            if (mem.startsWith(u8, user_input, ":exit")) {
                std.log.warn(":exit not implemented", .{});
            } else if (mem.eql(u8, user_input, ":list")) {
                if (peer_pool.items.len == 0) {
                    print("Peer list: []\n", .{});
                } else {
                    print("Peer list ({d}):\n", .{peer_pool.items.len});
                    for (peer_pool.items[0..]) |peer| {
                        peer_dump(peer);
                    }
                }
            } else if (mem.startsWith(u8, user_input, ":kill")) {
                const karrg = extract_command_val(user_input, ":kill");
                if (mem.eql(u8, karrg, "all")) {
                    for (peer_pool.items[0..]) |peer| {
                        const endp = ptc.Protocol.init(
                            ptc.Typ.RES,
                            ptc.Act.COMM_END,
                            ptc.StatusCode.OK,
                            "server",
                            "server",
                            "client",
                            "OK",
                        );
                        endp.dump(LOG_LEVEL);
                        _ = ptc.prot_transmit(peer.stream(), endp);
                    }
                    peer_pool.clearAndFree();
                } else {
                    const peer_ref = peer_find_ref(peer_pool, karrg);
                    if (peer_ref) |pf| {
                        try peer_kill(pf.ref_id, peer_pool);
                    }
                }
            } else if (mem.eql(u8, user_input, ":cc")) {
                try cmn.screen_clear();
                print("Server running on `{s}`\n", .{"127.0.0.1:6969"});
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

fn polizei(peer_pool: *std.ArrayList(Peer)) !void {
    _ = peer_pool;
    std.log.err("not implemented");
}

pub fn start() !void {
    try cmn.screen_clear();

    var server = try server_start(SERVER_ADDRESS, SERVER_PORT);
    errdefer server.deinit();
    defer server.deinit();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_allocator = gpa.allocator();

    //var messages = std.ArrayList(u8).init(gpa_allocator);
    //defer messages.deinit();

    var peer_pool = std.ArrayList(Peer).init(gpa_allocator);
    defer peer_pool.deinit();

    {
        const t1 = try std.Thread.spawn(.{}, server_core, .{ &server, &peer_pool });
        defer t1.join();
        const t2 = try std.Thread.spawn(.{}, read_cmd, .{&peer_pool});
        defer t2.join();
        //const t3 = try std.Thread.spawn(.{}, polizei, .{&peer_pool});
        //defer t3.join();
    }
}
