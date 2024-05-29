const std = @import("std");
const ptc = @import("ptc");
const cmn = @import("cmn");
const sqids = @import("sqids");
const net = std.net;
const mem = std.mem;
const print = std.debug.print;

const LOG_LEVEL = ptc.LogLevel.DEV;

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
    print("    un: `{s}`\n", .{p.username});
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
    return Peer.init(conn, id);
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
    ptc.prot_transmit(peer.stream(), endp);
    _ = peer_pool.orderedRemove(ref_id);
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
    const peer_ref = peer_find_ref(peer_pool, sender_id);
    if (peer_ref) |pf| {
        for (peer_pool.items[0..]) |peer| {
            if (pf.ref_id != pind) {
                const src_addr = cmn.address_to_str(pf.peer.comm_address());
                const dst_addr = cmn.address_to_str(peer.comm_address());
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
            var peer = peer_construct(conn);
            // DON'T EVER FORGET TO ALLOCATE MEMORY !!!!!!
            const aun = std.fmt.allocPrint(str_allocator, "{s}", .{protocol.body}) catch "format failed";
            peer.username = aun;
            peer_dump(peer);
            try peer_pool.append(peer);
            const resp = ptc.Protocol.init(
                ptc.Typ.RES,
                ptc.Act.COMM,
                ptc.StatusCode.OK,
                "server",
                "server",
                addr_str,
                peer.id,
            );
            resp.dump(LOG_LEVEL);
            ptc.prot_transmit(stream, resp);
        } else if (protocol.is_action(ptc.Act.COMM_END)) {
            const peer_ref = peer_find_ref(peer_pool, protocol.sender_id);
            if (peer_ref) |pf| {
                try peer_kill(pf.ref_id, peer_pool);
            }
        } else if (protocol.is_action(ptc.Act.MSG)) {
            try message_broadcast(peer_pool, protocol.sender_id, protocol.body);
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
            ptc.prot_transmit(stream, errp);
        }
    } else if (protocol.is_response()) {
        const errp = ptc.Protocol.init(
            ptc.Typ.ERR,
            protocol.action,
            ptc.StatusCode.METHOD_NOT_ALLOWED,
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
            ptc.StatusCode.BAD_REQUEST,
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

fn print_usage() void {
    print("COMMANDS:\n", .{});
    print("    * :list .............. list all active peers\n", .{});
    print("    * :kill all .......... kill all peers\n", .{});
    print("    * :kill <peer_id> .... kill one peer\n", .{});
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
            } else if (mem.startsWith(u8, user_input, ":list")) {
                if (peer_pool.items.len == 0) {
                    print("Peer list: []\n", .{});
                } else {
                    print("Peer list ({d}):\n", .{peer_pool.items.len});
                    for (peer_pool.items[0..]) |peer| {
                        peer_dump(peer);
                    }
                }
            } else if (mem.startsWith(u8, user_input, ":kill")) {
                var splits = mem.split(u8, user_input, ":kill");
                _ = splits.next().?; // the `:kill` part
                const id = mem.trimLeft(u8, splits.next().?, " \n");
                if (mem.eql(u8, id, "all")) {
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
                        ptc.prot_transmit(peer.stream(), endp);
                    }
                    peer_pool.clearAndFree();
                } else {
                    const peer_ref = peer_find_ref(peer_pool, id);
                    if (peer_ref) |pf| {
                        try peer_kill(pf.ref_id, peer_pool);
                    }
                }
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

    {
        const t1 = try std.Thread.spawn(.{}, server_core, .{ &server, &peer_pool });
        const t2 = try std.Thread.spawn(.{}, read_cmd, .{&peer_pool});
        t1.join();
        t2.join();
    }
}
