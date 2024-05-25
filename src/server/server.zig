const std = @import("std");
const ptc = @import("protocol.zig");
const net = std.net;
const mem = std.mem;
const print = std.debug.print;

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
    for (peer_pool.items[0..]) |peer| {
        const msgp = try ptc.Protocol.init("RES", "msg", sender_id, msg);
        const pstr = try msgp.as_str();
        _ = try peer.conn.stream.write(pstr);
        try msgp.dump();
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
    var protocol = try ptc.Protocol.init("", "", "", "");
    _ = try protocol.from_str(recv);
    try protocol.dump();

    if (mem.eql(u8, protocol.type, "REQ") and mem.eql(u8, protocol.action, "comm")) {
        const allocator = std.heap.page_allocator;
        const peer_id = std.fmt.allocPrint(allocator, "{d}", .{peer_pool.items.len + 1}) catch "format failed";
        const peer = Peer{
            .id = peer_id,
            .conn = conn,
        };
        try peer_pool.append(peer);
        const pres = std.fmt.allocPrint(allocator, "RES::comm::{s}::", .{peer.id}) catch "format failed";
        var res_prot = try ptc.Protocol.init("", "", "", "");
        try res_prot.from_str(pres);
        try res_prot.dump();
        _ = try stream.write(pres);
    } else if (mem.eql(u8, protocol.type, "REQ") and mem.eql(u8, protocol.action, "msg")) {
        try message_broadcast(peer_pool, protocol.id, protocol.body);
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
