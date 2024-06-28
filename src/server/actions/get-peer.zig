const std = @import("std");
const aids = @import("aids");
const core = @import("../core/core.zig");
const net = std.net;
const comm = aids.v2.comm;
const Action = aids.Stab.Action;
const SharedData = core.SharedData;

fn collectRequest(in_conn: ?net.Server.Connection, sd: *SharedData, protocol: comm.Protocol) void {
    _ = in_conn;
    const opt_server_peer_ref = sd.peerPoolFindId(protocol.sender_id);
    const opt_peer_ref = sd.peerPoolFindId(protocol.body);
    if (opt_server_peer_ref) |server_peer_ref| {
        const dst_addr = server_peer_ref.peer.commAddressAsStr();
        if (opt_peer_ref) |peer_ref| {
            const resp = comm.Protocol{
                .type = .RES, // type
                .action = .GET_PEER, // action
                .origin = .SERVER,
                .status = .OK, // status code
                .sender_id = "", // sender id
                .src_addr = sd.server.address_str, // src
                .dest_addr = dst_addr, // dst
                .body = peer_ref.peer.username, // body
            };
            resp.dump(sd.server.log_level);
            _ = resp.transmit(server_peer_ref.peer.stream()) catch 1;
        } else {
            const resp = comm.Protocol{
                .type = comm.Typ.ERR, // type
                .action = comm.Act.GET_PEER, // action
                .status = comm.Status.NOT_FOUND, // status code
                .origin = .SERVER,
                .sender_id = "", // sender id
                .src_addr = sd.server.address_str, // src
                .dest_addr = dst_addr, // dst, resp);
                .body = "peer not found", // body
            };
            resp.dump(sd.server.log_level);
            _ = resp.transmit(server_peer_ref.peer.stream()) catch 1;
        }
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
