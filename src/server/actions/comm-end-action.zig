const std = @import("std");
const aids = @import("aids");
const core = @import("../core/core.zig");
const cmn = aids.cmn;
const Protocol = aids.Protocol;
const net = std.net;
const Action = core.Action;
const SharedData = core.SharedData;
const Peer = core.Peer;

// TODO: try if sd.server.net_server can get the connection instead if in_conn param
fn collectRequest(in_conn: net.Server.Connection, sd: *SharedData, protocol: Protocol) void {
    _ = in_conn;
    const opt_peer_ref = core.PeerCore.peerRefFromId(sd.peer_pool, protocol.sender_id);
    if (opt_peer_ref) |peer_ref| {
        try sd.peerKill(sd.server, peer_ref.ref_id);
    }
}

fn collectRespone() void {
    std.log.err("not implemented", .{});
}

fn collectError() void {
    std.log.err("not implemented", .{});
}

fn transmitRequest() void {
    std.log.err("not implemented", .{});
}

fn transmitRespone() void {
    std.log.err("not implemented", .{});
}

fn transmitError() void {
    std.log.err("not implemented", .{});
}

pub const COMM_END_ACTION = Action{
    .collect = .{
        .request  = collectRequest,
        .response = collectRespone,
        .err      = collectError,
    },
    .transmit = .{
        .request  = transmitRequest,
        .response = transmitRespone,
        .err      = transmitError,
    },
};
