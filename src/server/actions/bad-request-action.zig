const std = @import("std");
const aids = @import("aids");
const core = @import("../core/core.zig");
const cmn = aids.cmn;
const Protocol = aids.Protocol;
const net = std.net;
const Action = core.Action;
const SharedData = core.SharedData;

fn collectRequest(in_conn: net.Server.Connection, sd: *SharedData, protocol: Protocol) void {
    const errp = Protocol.init(
        Protocol.Typ.ERR,
        protocol.action,
        Protocol.StatusCode.BAD_REQUEST,
        "server",
        sd.server.address_str,
        cmn.address_as_str(in_conn.address),
        @tagName(Protocol.StatusCode.BAD_REQUEST),
    );
    errp.dump(sd.server.log_level);
    _ = Protocol.transmit(in_conn.stream, errp);
}

fn collectRespone(sd: *SharedData, protocol: Protocol) void {
    _ = sd;
    _ = protocol;
    std.log.err("not implemented", .{});
}

fn collectError() void {
    std.log.err("not implemented", .{});
}

fn transmitRequest(mode: Protocol.TransmitionMode, sd: *SharedData, _: []const u8) void {
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
