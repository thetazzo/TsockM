const std = @import("std");
const aids = @import("aids");
const core = @import("../core/core.zig");
const proto = aids.Protocol;
const net = std.net;
const Action = aids.Stab.Action;
const SharedData = core.SharedData;

fn collectRequest(in_conn: ?net.Server.Connection, sd: *SharedData, protocol: proto.Protocol) void {
    _ = in_conn;
    const opt_server_peer_ref = core.PeerCore.peerRefFromId(sd.peer_pool, protocol.sender_id);
    const opt_peer_ref = core.PeerCore.peerRefFromId(sd.peer_pool, protocol.body);
    if (opt_server_peer_ref) |server_peer_ref| {
        if (opt_peer_ref) |peer_ref| {
            const dst_addr = server_peer_ref.peer.commAddressAsStr();
            const resp = proto.Protocol.init(
                proto.Typ.RES, // type
                proto.Act.GET_PEER, // action
                proto.StatusCode.OK, // status code
                "server", // sender id
                sd.server.address_str, // src
                dst_addr, // dst
                peer_ref.peer.username, // body
            );
            resp.dump(sd.server.log_level);
            _ = proto.transmit(server_peer_ref.peer.stream(), resp);
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
