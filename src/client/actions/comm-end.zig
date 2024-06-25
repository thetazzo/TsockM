const std = @import("std");
const aids = @import("aids");
const core = @import("../core/core.zig");
const Message = @import("../ui/display.zig").Message;
const Protocol = aids.Protocol;
const net = std.net;
const Action = aids.Stab.Action;
const SharedData = core.SharedData;

fn collectRequest(_: ?net.Server.Connection, sd: *SharedData, protocol: Protocol) void {
    if (protocol.status_code == Protocol.StatusCode.OK) {
        sd.setShouldExit(true);
        return;
    }
}

fn collectRespone(sd: *SharedData, protocol: Protocol) void {
    _ = sd;
    _ = protocol;
    // if (protocol.status_code == Protocol.StatusCode.OK) {
    //     sd.setShouldExit(true);
    // }
}

fn collectError(_: *SharedData) void {
    std.log.err("not implemented", .{});
}

fn transmitRequest(_: Protocol.TransmitionMode, sd: *SharedData, _: []const u8) void {
    const reqp = aids.Protocol.init(
        aids.Protocol.Typ.REQ,
        aids.Protocol.Act.COMM_END,
        aids.Protocol.StatusCode.OK,
        sd.client.id,
        sd.client.client_addr_str,
        sd.client.server_addr_str,
        "OK",
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
