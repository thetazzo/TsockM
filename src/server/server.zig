const std = @import("std");
const ptc = @import("ptc");
const cmn = @import("cmn");
const net = std.net;
const mem = std.mem;
const print = std.debug.print;

const LOG_LEVEL = ptc.LogLevel.DEV;

const PEER_ID = []const u8;

const Peer = struct {
    conn: net.Server.Connection,
    id: PEER_ID,
    pub fn init(conn: net.Server.Connection, id: PEER_ID) Peer {
        // TODO: check for peer.id collisions
        return Peer{
            .conn = conn,
            .id = id,
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
    print("    comm_addr: `{any}`\n", .{p.comm_address()});
    print("}}\n", .{});
    print("------------------------------------\n", .{});
}

fn find_peer_ref(
    peer_pool: *std.ArrayList(Peer),
    id: []const u8,
) ?struct { peer: Peer, i: usize } {
    // O(n)
    var i: usize = 0;
    for (peer_pool.items[0..]) |peer| {
        if (mem.eql(u8, peer.id, id)) {
            return .{ .peer = peer, .i = i };
        }
        i += 1;
    }
    return null;
}

fn peer_construct(
    conn: net.Server.Connection,
    username: []const u8,
) Peer {
    var rand = std.rand.DefaultPrng.init(@as(u64, @bitCast(std.time.milliTimestamp())));
    const peer_id = cmn.usize_to_str(rand.random().int(u8));
    //var block = [_]u8{0} ** std.crypto.hash.Md5.block_length;
    //var out: [std.crypto.hash.Md5.digest_length]u8 = undefined;
    //var h = std.crypto.hash.Md5.init(.{});
    //h.update(&block);
    //h.update(username);
    //h.final(out[0..]);
    //const allocator = std.heap.page_allocator;
    //const id = std.fmt.allocPrint(allocator, "{s}", .{out}) catch "format failed";
    _ = username;
    return Peer.init(conn, peer_id);
}

fn peer_kill(
    peer_pool: *std.ArrayList(Peer),
    id: PEER_ID,
    src_addr: ptc.Addr,
) !void {
    const peer_ref = find_peer_ref(peer_pool, id);
    if (peer_ref) |pf| {
        //const addr_str = cmn.address_to_str(pf.peer.conn.address);
        const endp = ptc.Protocol.init(
            ptc.Typ.RES,
            ptc.Act.COMM_END,
            ptc.RetCode.OK,
            id,
            src_addr,
            "client",
            "OK",
        );
        endp.dump(LOG_LEVEL);
        ptc.prot_transmit(pf.peer.stream(), endp);
        _ = peer_pool.orderedRemove(pf.i);
        print("Remaining peers {d}\n", .{peer_pool.items.len});
    }
}

fn localhost_server(port: u16) !net.Server {
    const lh = try net.Address.resolveIp("127.0.0.1", port);
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
    const peer_ref = find_peer_ref(peer_pool, sender_id);
    if (peer_ref) |pf| {
        for (peer_pool.items[0..]) |peer| {
            if (pf.i != pind) {
                const src_addr = cmn.address_to_str(pf.peer.comm_address());
                const dst_addr = cmn.address_to_str(peer.comm_address());
                const msgp = ptc.Protocol.init(
                    ptc.Typ.RES,
                    ptc.Act.MSG,
                    ptc.RetCode.OK,
                    sender_id,
                    src_addr,
                    dst_addr,
                    msg,
                );
                msgp.dump(LOG_LEVEL);
                ptc.prot_transmit(peer.stream(), msgp);
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

    const addr_str = cmn.address_to_str(conn.address);
    if (protocol.is_request()) {
        if (protocol.is_action(ptc.Act.COMM)) {
            const peer = peer_construct(conn, protocol.sender_id);
            try peer_pool.append(peer);
            const resp = ptc.Protocol.init(
                ptc.Typ.RES,
                ptc.Act.COMM,
                ptc.RetCode.OK,
                "server",
                "server",
                addr_str,
                peer.id,
            );
            resp.dump(LOG_LEVEL);
            ptc.prot_transmit(stream, resp);
        } else if (protocol.is_action(ptc.Act.COMM_END)) {
            try peer_kill(peer_pool, protocol.sender_id, protocol.src);
        } else if (protocol.is_action(ptc.Act.MSG)) {
            try message_broadcast(peer_pool, protocol.sender_id, protocol.body);
        } else if (protocol.is_action(ptc.Act.NONE)) {
            const errp = ptc.Protocol.init(
                ptc.Typ.ERR,
                protocol.action,
                ptc.RetCode.BAD_REQUEST,
                "server",
                "server",
                addr_str,
                @tagName(ptc.RetCode.BAD_REQUEST),
            );
            errp.dump(LOG_LEVEL);
            ptc.prot_transmit(stream, errp);
        }
    } else if (protocol.is_response()) {
        const errp = ptc.Protocol.init(
            ptc.Typ.ERR,
            protocol.action,
            ptc.RetCode.METHOD_NOT_ALLOWED,
            "server",
            "server",
            addr_str,
            "method not allowed:\n  NOTE: Server can only process REQUESTS for now",
        );
        errp.dump(LOG_LEVEL);
        ptc.prot_transmit(stream, errp);
    } else if (protocol.type == ptc.Typ.NONE) {
        const errp = ptc.Protocol.init(
            ptc.Typ.ERR,
            protocol.action,
            ptc.RetCode.BAD_REQUEST,
            "server",
            "server",
            addr_str,
            "bad request",
        );
        errp.dump(LOG_LEVEL);
        ptc.prot_transmit(stream, errp);
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

fn read_cmd(peer_pool: *std.ArrayList(Peer)) !void {
    _ = peer_pool;
    while (true) {
        // read for command
        var buf: [256]u8 = undefined;
        const stdin = std.io.getStdIn().reader();
        if (try stdin.readUntilDelimiterOrEof(buf[0..], '\n')) |user_input| {
            // Handle different commands
            if (mem.startsWith(u8, user_input, ":exit")) {
                print("Exiting!\n", .{});
                break;
            } else if (mem.startsWith(u8, user_input, ":help")) {
                //print_usage();
            } else {
                print("Unknown command: `{s}`\n", .{user_input});
                //print_usage();
            }
        } else {
            print("Unreachable, maybe?\n", .{});
        }
    }
    print("Thread `run_cmd` finished\n", .{});
}

pub fn start() !void {
    // create a localhost server
    var server = try localhost_server(6969);
    errdefer server.deinit();
    defer server.deinit();

    print("Server running on `{s}`\n", .{"127.0.0.1:6969"});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var messages = std.ArrayList(u8).init(allocator);
    defer messages.deinit();

    var peer_pool = std.ArrayList(Peer).init(allocator);
    defer peer_pool.deinit();

    while (true) {
        const conn = try server.accept();
        try read_incomming(&peer_pool, conn);
    }
}
