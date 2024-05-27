const std = @import("std");
const ptc = @import("ptc");
const cmn = @import("cmn");
const net = std.net;
const mem = std.mem;
const print = std.debug.print;

var SILENT = false;

const Peer = struct {
    conn: net.Server.Connection,
    id: []const u8,
};

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
        if (pind != psid) {
            const msgp = ptc.Protocol.init(ptc.ProtType.RES, ptc.ProtAct.MSG, sender_id, msg);
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
        if (protocol.is_action(ptc.ProtAct.COMM)) {
            const peer_id = cmn.usize_to_str(peer_pool.items.len + 1);
            const peer = Peer{
                .id = peer_id,
                .conn = conn,
            };
            try peer_pool.append(peer);
            const resp = ptc.Protocol.init(ptc.ProtType.RES, ptc.ProtAct.COMM, peer.id, "");
            if (!SILENT) {
                resp.dump();
            }
            _ = try stream.write(try resp.as_str());
        } else if (protocol.is_action(ptc.ProtAct.MSG)) {
            try message_broadcast(peer_pool, protocol.id, protocol.body);
        }
    } else if (protocol.is_response()) {
        std.log.err("TODO: RES handling not implemented", .{});
        std.posix.exit(1);
    } else {
        std.log.err("unreachable code", .{});
        std.posix.exit(1);
    }
}

pub fn start() !void {
    // create a localhost server
    var server = try localhost_server(6969);
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
