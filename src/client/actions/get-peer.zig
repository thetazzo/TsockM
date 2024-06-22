const std = @import("std");
const aids = @import("aids");
const core = @import("../core/core.zig");
const Protocol = aids.Protocol;
const net = std.net;
const Action = aids.Stab.Action;
const SharedData = core.SharedData;

fn collectRequest(in_conn: ?net.Server.Connection, sd: *SharedData, protocol: Protocol) void {
    _ = in_conn;
    _ = sd;
    _ = protocol;
    std.log.err("not implemented", .{});
}

fn collectRespone(sd: *SharedData, protocol: Protocol) void {
    _ = sd;
    _ = protocol;
    std.log.err("not implemented", .{});
}

fn collectError(_:*SharedData) void {
    std.log.err("not implemented", .{});
}

fn transmitRequest(mode: Protocol.TransmitionMode, sd: *SharedData, sender_id: []const u8) void {
    switch (mode) {
        .UNICAST => {
            const reqp = Protocol.init(
                Protocol.Typ.REQ, // type
                Protocol.Act.GET_PEER, // action
                Protocol.StatusCode.OK, // status code
                sd.client.id, // sender id
                sd.client.client_addr_str, // src address
                sd.client.server_addr_str, // destination address
                sender_id, //body
            );
            sd.client.sendRequestToServer(reqp);
        },
        .BROADCAST => {
            std.log.err("not implemented", .{});
            std.posix.exit(1);
        }
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
