const std = @import("std");
const aids = @import("aids");
const core = @import("../core/core.zig");
const cmn = aids.cmn;
const Protocol = aids.Protocol;
const net = std.net;
const Action = core.Action;
const SharedData = core.SharedData;
const Peer = core.Peer;

fn collectRequest(in_conn: net.Server.Connection, sd: *SharedData, protocol: Protocol) void {
    _ = in_conn;
    const opt_peer_ref = core.PeerCore.peerRefFromId(sd.peer_pool, protocol.sender_id);
    if (opt_peer_ref) |peer_ref| {
        for (sd.peer_pool.items, 0..) |peer, pid| {
            if (peer_ref.ref_id != pid and peer.alive) {
                const src_addr = peer_ref.peer.commAddressAsStr();
                const dst_addr = peer.commAddressAsStr();
                const msgp = Protocol.init(
                    Protocol.Typ.RES,
                    Protocol.Act.MSG,
                    Protocol.StatusCode.OK,
                    protocol.sender_id,
                    src_addr,
                    dst_addr,
                    protocol.body,
                );
                msgp.dump(sd.server.log_level);
                _ = Protocol.transmit(peer.stream(), msgp);
            }
        }
    }
}

fn collectRespone(sd: *SharedData, protocol: Protocol) void {
    _ = sd;
    _ = protocol;
    std.log.err("not implemented", .{});
}

fn collectError() void {
    std.log.err("not implemented", .{});
}

fn transmitRequest(mode: Protocol.TransmitionMode, sd: *SharedData) void {
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

pub const ACTION = Action{
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
    .internal = null,
};
