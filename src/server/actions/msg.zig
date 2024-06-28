const std = @import("std");
const aids = @import("aids");
const core = @import("../core/core.zig");
const net = std.net;
const comm = aids.v2.comm;
const Action = aids.Stab.Action;
const SharedData = core.SharedData;

fn broadcastMessage(sd: *SharedData, peer_ref: core.pc.PeerRef, sender_id: []const u8, message: []const u8) void {
    for (sd.peer_pool.items, 0..) |peer, pid| {
        if (peer_ref.ref_id != pid and peer.alive) {
            const src_addr = peer_ref.peer.commAddressAsStr();
            const dst_addr = peer.commAddressAsStr();
            const resp = comm.Protocol{
                .type = .RES,
                .action = .MSG,
                .status_code = .OK,
                .sender_id = sender_id,
                .src_addr = src_addr,
                .dest_addr = dst_addr,
                .body = message,
            };
            resp.dump(sd.server.log_level);
            _ = resp.transmit(peer.stream()) catch 1;
        }
    }
}

fn collectRequest(in_conn: ?net.Server.Connection, sd: *SharedData, protocol: comm.Protocol) void {
    _ = in_conn;
    const opt_peer_ref = core.pc.peerRefFromId(sd.peer_pool, protocol.sender_id);
    if (opt_peer_ref) |peer_ref| {
        broadcastMessage(sd, peer_ref, protocol.sender_id, protocol.body);
        const src_addr = peer_ref.peer.commAddressAsStr();
        const dst_addr = src_addr;
        const resp = comm.Protocol{
            .type = .RES,
            .action = .MSG,
            .status_code = .OK,
            .sender_id = protocol.sender_id,
            .src_addr = src_addr,
            .dest_addr = dst_addr,
            .body = "OK",
        };
        resp.dump(sd.server.log_level);
        _ = resp.transmit(peer_ref.peer.stream()) catch 1;
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
