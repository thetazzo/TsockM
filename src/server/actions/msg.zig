const std = @import("std");
const aids = @import("aids");
const core = @import("../core/core.zig");
const net = std.net;
const comm = aids.v2.comm;
const Action = aids.Stab.Action;
const SharedData = core.SharedData;

fn broadcastMessage(sd: *SharedData, peer: core.Peer, sender_id: []const u8, message: []const u8) void {
    for (sd.peer_pool.peers) |opt_peer| {
        if (opt_peer) |pool_peer| {
            if (!std.mem.eql(u8, pool_peer.id, peer.id) and pool_peer.alive) {
                const src_addr_str = peer.conn_address_str;
                const dest_addr_str = pool_peer.conn_address_str;
                const resp = comm.Protocol{
                    .type = .RES,
                    .action = .MSG,
                    .status = .OK,
                    .origin = .SERVER,
                    .sender_id = sender_id,
                    .src_addr = src_addr_str,
                    .dest_addr = dest_addr_str,
                    .body = message,
                };
                resp.dump(sd.server.log_level);
                _ = resp.transmit(pool_peer.stream()) catch 1;
            }
        }
    }
}

// NOTE: peer does not get bound to communution in COMM server action
fn collectRequest(in_conn: ?net.Server.Connection, sd: *SharedData, protocol: comm.Protocol) void {
    _ = in_conn;
    const opt_peer = sd.peer_pool.get(protocol.sender_id);
    if (opt_peer) |peer| {
        broadcastMessage(sd, peer, protocol.sender_id, protocol.body);
        const src_addr_str = peer.conn_address_str;
        const dest_addr_str = src_addr_str;
        const resp = comm.Protocol{
            .type = .RES,
            .action = .MSG,
            .status = .OK,
            .origin = .SERVER,
            .sender_id = protocol.sender_id,
            .src_addr = src_addr_str,
            .dest_addr = dest_addr_str,
            .body = "OK",
        };
        resp.dump(sd.server.log_level);
        _ = resp.transmit(peer.stream()) catch 1;
        peer.dump();
        @panic("eze");
    }
}

fn collectRespone(sd: *SharedData, protocol: comm.Protocol) void {
    _ = sd;
    _ = protocol;
    std.log.err("not implemented", .{});
}

fn collectError(_: *SharedData) void {
    std.log.err("not implemented", .{});
}

fn transmitRequest(mode: comm.TransmitionMode, sd: *SharedData, _: []const u8) void {
    _ = mode;
    _ = sd;
    std.log.err("not implemented", .{});
}

fn transmitRespone() void {
    std.log.err("not implemented", .{});
}

fn transmitError() void {
    std.log.err("not implemented", .{});
}

pub const ACTION = Action(SharedData){
    .collect = .{
        .request = collectRequest,
        .response = collectRespone,
        .err = collectError,
    },
    .transmit = .{
        .request = transmitRequest,
        .response = transmitRespone,
        .err = transmitError,
    },
    .internal = null,
};
