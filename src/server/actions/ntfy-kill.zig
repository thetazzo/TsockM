const std = @import("std");
const aids = @import("aids");
const core = @import("../core/core.zig");
const proto = aids.Protocol;
const net = std.net;
const Action = aids.Stab.Action;
const SharedData = core.SharedData;

fn collectRequest(in_conn: ?net.Server.Connection, sd: *SharedData, protocol: proto.Protocol) void {
    _ = in_conn;
    _ = sd;
    _ = protocol;
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
    switch (mode) {
        .UNICAST => {
            std.log.err("not implemented", .{});
            unreachable;
        },
        .BROADCAST => {
            for (sd.peer_pool.items) |peer| {
                if (peer.alive == false) {
                    // TODO: peer_broadcast_death
                    for (sd.peer_pool.items) |ap| {
                        if (!std.mem.eql(u8, ap.id, peer.id)) {
                            const ntfy = proto.Protocol.init(
                                proto.Typ.REQ,
                                proto.Act.NTFY_KILL,
                                proto.StatusCode.OK,
                                "server",
                                sd.server.address_str,
                                peer.commAddressAsStr(),
                                peer.id,
                            );
                            _ = proto.transmit(ap.stream(), ntfy);
                        }
                    }
                }
            }
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
