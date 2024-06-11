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
        const peer = sd.peer_pool.items[peer_ref.ref_id];
        const endp = Protocol.init(
            Protocol.Typ.REQ,
            Protocol.Act.COMM_END,
            Protocol.StatusCode.OK,
            "server",
            sd.server.address_str,
            peer.commAddressAsStr(),
            "OK",
        );
        endp.dump(sd.server.log_level);
        _ = Protocol.transmit(peer.stream(), endp);
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

fn transmitRequest(mode: Protocol.TransmitionMode, sd: *SharedData, request_data: []const u8) void {
    switch (mode) {
        .UNICAST => {
            const ref_id = std.fmt.parseInt(usize, request_data, 10) catch |err| {
                std.log.err("provided request data `{any}` is not a number\n{any}", .{request_data, err});
                return;
            };
            const peer = sd.peer_pool.items[ref_id];
            const endp = Protocol.init(
                Protocol.Typ.REQ,
                Protocol.Act.COMM_END,
                Protocol.StatusCode.OK,
                "server",
                sd.server.address_str,
                peer.commAddressAsStr(),
                "OK",
            );
            endp.dump(sd.server.log_level);
            _ = Protocol.transmit(peer.stream(), endp);
        },
        .BROADCAST => {
            for (sd.peer_pool.items[0..]) |peer| {
                const endp = Protocol.init(
                Protocol.Typ.REQ,
                Protocol.Act.COMM_END,
                Protocol.StatusCode.OK,
                "server",
                sd.server.address_str,
                peer.commAddressAsStr(),
                "OK",
            );
                endp.dump(sd.server.log_level);
                _ = Protocol.transmit(peer.stream(), endp);
            }
            sd.clearPeerPool();
        }
    }
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
