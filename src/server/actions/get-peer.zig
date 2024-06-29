const std = @import("std");
const aids = @import("aids");
const core = @import("../core/core.zig");
const net = std.net;
const comm = aids.v2.comm;
const Action = aids.Stab.Action;
const SharedData = core.SharedData;

fn collectRequest(in_conn: ?net.Server.Connection, sd: *SharedData, protocol: comm.Protocol) void {
    _ = in_conn;
    const opt_sender_peer_ref = sd.peerPoolFindId(protocol.sender_id);
    const opt_search_peer_ref = sd.peerPoolFindId(protocol.body);
    if (opt_sender_peer_ref) |server_peer_ref| {
        const dest_addr_str = server_peer_ref.peer.conn_address_str;
        if (opt_search_peer_ref) |peer_ref| {
            const resp = comm.Protocol{
                .type = .RES,
                .action = .GET_PEER,
                .origin = .SERVER,
                .status = .OK,
                .sender_id = "",
                .src_addr = sd.server.address_str,
                .dest_addr = dest_addr_str,
                .body = peer_ref.peer.username,
            };
            resp.dump(sd.server.log_level);
            _ = resp.transmit(server_peer_ref.peer.stream()) catch 1;
        } else {
            const resp = comm.Protocol{
                .type = comm.Typ.ERR,
                .action = comm.Act.GET_PEER,
                .status = comm.Status.NOT_FOUND,
                .origin = .SERVER,
                .sender_id = "",
                .src_addr = sd.server.address_str,
                .dest_addr = dest_addr_str,
                .body = "peer not found",
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
