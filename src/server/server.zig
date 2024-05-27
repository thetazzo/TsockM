const std = @import("std");
const ptc = @import("ptc");
const cmn = @import("cmn");
const net = std.net;
const mem = std.mem;
const print = std.debug.print;

var SILENT = false;

const PEER_ID = []const u8;

const Peer = struct {
    conn: net.Server.Connection,
    id: PEER_ID,
    alive: bool,
    pub fn Init(conn: net.Server.Connection, id: PEER_ID) Peer {
        // TODO: check for peer.id collisions
        return Peer{
            .conn = conn,
            .id = id,
            .alive = true,
        };
    }
};

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
) Peer {
    var rand = std.rand.DefaultPrng.init(@as(u64, @bitCast(std.time.milliTimestamp())));
    const peer_id = cmn.usize_to_str(rand.random().int(u8));
    return Peer.Init(conn, peer_id);
}

fn peer_kill(
    peer_pool: *std.ArrayList(Peer),
    id: PEER_ID,
) !void {
    const peer_ref = find_peer_ref(peer_pool, id);
    if (peer_ref) |pf| {
        const endp = ptc.Protocol.init(ptc.Typ.RES, ptc.Act.COMM_END, "200", "OK");
        if (!SILENT) {
            print("Peer `{s}` at `{d}` killed\n", .{ pf.peer.id, pf.i });
            endp.dump();
        }
        _ = try peer_pool.items[pf.i].conn.stream.write(try endp.as_str());
        peer_pool.items[pf.i].conn.stream.close();
        _ = peer_pool.orderedRemove(pf.i);
    }
}

fn localhost_server(port: u16) !net.Server {
    const lh = try net.Address.resolveIp("127.0.0.1", port);
    return lh.listen(.{});
}

fn listen_for_messages(owner: net.Stream, peer: net.Stream, ind: u8) !void {
    while (true) {
        var buff: [256]u8 = undefined;
        _ = try owner.read(&buff);
        const trimm = mem.sliceTo(&buff, 170);
        if (ind == 1) {
            _ = try peer.write("peer 1: ");
        } else if (ind == 2) {
            _ = try peer.write("peer 2: ");
        }
        _ = try peer.write(trimm);
    }
}

fn message_broadcast(
    peer_pool: *std.ArrayList(Peer),
    sender_id: []const u8,
    msg: []const u8,
) !void {
    var pind: usize = 1;
    const psid = try std.fmt.parseInt(usize, sender_id, 10);
    for (peer_pool.items[0..]) |peer| {
        if (pind != psid and peer.alive) {
            const msgp = ptc.Protocol.init(ptc.Typ.RES, ptc.Act.MSG, sender_id, msg);
            msgp.dump();
            _ = try peer.conn.stream.write(try msgp.as_str());
        }
        pind += 1;
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
    if (!SILENT) {
        protocol.dump();
    }

    if (protocol.is_request()) {
        if (protocol.is_action(ptc.Act.COMM)) {
            const peer = peer_construct(conn);
            try peer_pool.append(peer);
            const resp = ptc.Protocol.init(ptc.Typ.RES, ptc.Act.COMM, peer.id, "");
            if (!SILENT) {
                resp.dump();
            }
            _ = try stream.write(try resp.as_str());
        } else if (protocol.is_action(ptc.Act.COMM_END)) {
            print("kill peer `{s}`\n", .{protocol.id});
            try peer_kill(peer_pool, protocol.id);
        } else if (protocol.is_action(ptc.Act.MSG)) {
            try message_broadcast(peer_pool, protocol.id, protocol.body);
        } else if (protocol.is_action(ptc.Act.NONE)) {
            const errp = ptc.Protocol.init(ptc.Typ.ERR, protocol.action, "400", "bad request");
            _ = try stream.write(try errp.as_str());
        }
    } else if (protocol.is_response()) {
        const errp = ptc.Protocol.init(ptc.Typ.ERR, protocol.action, "405", "method not allowed:\n  NOTE: Server can only process REQUESTS for now");
        _ = try stream.write(try errp.as_str());
    } else if (protocol.type == ptc.Typ.NONE) {
        const errp = ptc.Protocol.init(ptc.Typ.ERR, protocol.action, "400", "bad request");
        _ = try stream.write(try errp.as_str());
    } else {
        std.log.err("unreachable code", .{});
    }
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

    // read incomming requests
    while (true) {
        const conn = try server.accept();
        try read_incomming(&peer_pool, conn);
    }
}
