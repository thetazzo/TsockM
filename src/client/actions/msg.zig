const std = @import("std");
const aids = @import("aids");
const core = @import("../core/core.zig");
const Message = @import("../ui/display.zig").Message;
const Protocol = aids.Protocol;
const net = std.net;
const Action = aids.Stab.Action;
const SharedData = core.SharedData;

fn collectRequest(in_conn: net.Server.Connection, sd: *SharedData, protocol: Protocol) void {
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

fn collectError() void {
    std.log.err("not implemented", .{});
}

fn transmitRequest(_: Protocol.TransmitionMode, sd: *SharedData, msg: []const u8) void {
    // handle sending a message
    const reqp = Protocol.init(
        Protocol.Typ.REQ,
        Protocol.Act.MSG,
        Protocol.StatusCode.OK,
        sd.client.id,
        sd.client.client_addr_str,
        sd.client.server_addr_str,
        msg,
    );
    sd.client.sendRequestToServer(reqp);
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
