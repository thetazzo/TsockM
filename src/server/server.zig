const std = @import("std");
const ptc = @import("protocol.zig");
const net = std.net;
const mem = std.mem;
const print = std.debug.print;
//////////////////////////////////////////////////
/// Move to protocol.zig
//////////////////////////////////////////////////
const Protocol = struct {
    type: []const u8,
    action: []const u8,
    id: []const u8,
    body: []const u8,
};

fn protocol_build(req: []const u8, proto: *Protocol) !void {
    var pts = mem.split(u8, req, "::");
    if (pts.next()) |typ| {
        proto.type = typ;
    }
    if (pts.next()) |act| {
        proto.action = act;
    }
    if (pts.next()) |id| {
        proto.id = id;
    }
    if (pts.next()) |bdy| {
        proto.body = bdy;
    }
}
//////////////////////////////////////////////////

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
    peer_pool: *std.ArrayList(net.Server.Connection),
    msg: []const u8,
) !void {
    for (peer_pool.items[0..]) |peer| {
        _ = try peer.stream.write(msg);
        print("Sent `OK` to {any}\n", .{peer.address});
    }
}

fn read_incomming(
    peer_pool: *std.ArrayList(net.Server.Connection),
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
        try peer_pool.append(conn);
        const allocator = std.heap.page_allocator;
        const pres = std.fmt.allocPrint(allocator, "RES::comm::{d}::", .{peer_pool.items.len}) catch "format failed";
        var res_prot = try ptc.Protocol.init("", "", "", "");
        try res_prot.from_str(pres);
        try res_prot.dump();
        _ = try stream.write(pres);
    } else if (mem.eql(u8, protocol.type, "REQ") and mem.eql(u8, protocol.action, "msg")) {
        try message_broadcast(peer_pool, protocol.body);
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

    var peer_pool = std.ArrayList(net.Server.Connection).init(allocator);
    defer peer_pool.deinit();

    // read incomming requests
    while (true) {
        const conn = try server.accept();
        try read_incomming(&peer_pool, conn);
    }
}
