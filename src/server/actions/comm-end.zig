const std = @import("std");
const aids = @import("aids");
const core = @import("../core/core.zig");
const net = std.net;
const comm = aids.v2.comm;
const Action = aids.Stab.Action;
const SharedData = core.SharedData;

// TODO: try if sd.server.net_server can get the connection instead if in_conn param
fn collectRequest(in_conn: ?net.Server.Connection, sd: *SharedData, protocol: comm.Protocol) void {
    _ = in_conn;
    const opt_peer_ref = sd.peerPoolFindId(protocol.sender_id);
    if (opt_peer_ref) |peer_ref| {
        const peer = sd.peer_pool.items[peer_ref.ref_id];
        const resp = comm.Protocol{
            .type = .RES,
            .action = .COMM_END,
            .status = .OK,
            .origin = .SERVER,
            .sender_id = "",
            .src_addr = sd.server.address_str,
            .dest_addr = peer.conn_address_str,
            .body = "OK",
        };
        resp.dump(sd.server.log_level);
        _ = resp.transmit(peer.stream()) catch 1;
        sd.markPeerForDeath(peer_ref.ref_id);
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

fn transmitRequest(mode: comm.TransmitionMode, sd: *SharedData, request_data: []const u8) void {
    switch (mode) {
        .UNICAST => {
            const ref_id = std.fmt.parseInt(usize, request_data, 10) catch |err| {
                std.log.err("provided request data `{any}` is not a number\n{any}", .{ request_data, err });
                return;
            };
            const peer = sd.peer_pool.items[ref_id];
            const reqp = comm.Protocol{
                .type = comm.Typ.REQ,
                .action = comm.Act.COMM_END,
                .status = comm.Status.OK,
                .origin = .SERVER,
                .sender_id = "",
                .src_addr = sd.server.address_str,
                .dest_addr = peer.conn_address_str,
                .body = "OK",
            };
            reqp.dump(sd.server.log_level);
            _ = reqp.transmit(peer.stream()) catch 1;
        },
        .BROADCAST => {
            for (sd.peer_pool.items[0..]) |peer| {
                const reqp = comm.Protocol{
                    .type = comm.Typ.REQ,
                    .action = comm.Act.COMM_END,
                    .status = comm.Status.OK,
                    .origin = .SERVER,
                    .sender_id = "",
                    .src_addr = sd.server.address_str,
                    .dest_addr = peer.conn_address_str,
                    .body = "OK",
                };
                reqp.dump(sd.server.log_level);
                _ = reqp.transmit(peer.stream()) catch 1;
            }
            sd.peerPoolClear();
        },
    }
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
