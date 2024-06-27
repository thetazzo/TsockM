const std = @import("std");
const aids = @import("aids");
const core = @import("../core/core.zig");
const proto = aids.proto;
const net = std.net;
const Action = aids.Stab.Action;
const SharedData = core.SharedData;

fn collectRequest(in_conn: ?net.Server.Connection, sd: *SharedData, protocol: proto.Protocol) void {
    _ = in_conn;
    const opt_peer_ref = core.pc.peerRefFromId(sd.peer_pool, protocol.sender_id);
    if (opt_peer_ref) |peer_ref| {
        for (sd.peer_pool.items, 0..) |peer, pid| {
            if (peer_ref.ref_id != pid and peer.alive) {
                const src_addr = peer_ref.peer.commAddressAsStr();
                const dst_addr = peer.commAddressAsStr();
                const msgp = proto.Protocol.init(
                    proto.Typ.RES,
                    proto.Act.MSG,
                    proto.StatusCode.OK,
                    protocol.sender_id,
                    src_addr,
                    dst_addr,
                    protocol.body,
                );
                msgp.dump(sd.server.log_level);
                _ = proto.transmit(peer.stream(), msgp);
            }
        }
    }
}

fn collectRespone(sd: *SharedData, protocol: proto.Protocol) void {
    _ = sd;
    _ = protocol;
    std.log.err("not implemented", .{});
}

fn collectError(_: *SharedData) void {
    std.log.err("not implemented", .{});
}

fn transmitRequest(mode: proto.TransmitionMode, sd: *SharedData, _: []const u8) void {
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
