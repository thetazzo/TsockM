const std = @import("std");
const aids = @import("aids");
const core = @import("../core/core.zig");
const net = std.net;
const comm = aids.v2.comm;
const Action = aids.Stab.Action;
const SharedData = core.SharedData;

// TODO: try if sd.server.net_server can get the connection instead if in_conn param
///This occurs when a client requests a tqermination
///Ussulay happens when the client exits
fn collectRequest(in_conn: ?net.Server.Connection, sd: *SharedData, protocol: comm.Protocol) void {
    _ = in_conn;
    const opt_peer = sd.peer_pool.get(protocol.sender_id);
    if (opt_peer) |peer| {
        var mut_peer = peer;
        const resp = comm.Protocol{
            .type = .RES,
            .action = .COMM_END,
            .status = .OK,
            .origin = .SERVER,
            .sender_id = "",
            .src_addr = sd.server.address_str,
            .dest_addr = mut_peer.conn_address_str,
            .body = "OK",
        };
        resp.dump(sd.server.log_level);
        _ = resp.transmit(mut_peer.stream()) catch 1;
        mut_peer.alive = false;
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

///This happens when the server kills a peer
fn transmitRequest(mode: comm.TransmitionMode, sd: *SharedData, request_data: []const u8) void {
    switch (mode) {
        .UNICAST => {
            _ = request_data;
            @panic("Not implemented yet");
            //const ref_id = std.fmt.parseInt(usize, request_data, 10) catch |err| {
            //    std.log.err("provided request data `{any}` is not a number\n{any}", .{ request_data, err });
            //    return;
            //};
            //const peer = sd.peer_pool.items[ref_id];
            //const reqp = comm.Protocol{
            //    .type = comm.Typ.REQ,
            //    .action = comm.Act.COMM_END,
            //    .status = comm.Status.OK,
            //    .origin = .SERVER,
            //    .sender_id = "",
            //    .src_addr = sd.server.address_str,
            //    .dest_addr = peer.conn_address_str,
            //    .body = "OK",
            //};
            //reqp.dump(sd.server.log_level);
            //_ = reqp.transmit(peer.stream()) catch 1;
        },
        .BROADCAST => {
            for (sd.peer_pool.peers) |opt_peer| {
                if (opt_peer) |peer| {
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
