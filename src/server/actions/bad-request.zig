const std = @import("std");
const aids = @import("aids");
const core = @import("../core/core.zig");
const cmn = aids.cmn;
const proto = aids.Protocol;
const net = std.net;
const Action = aids.Stab.Action;
const SharedData = core.SharedData;

fn collectRequest(in_conn: ?net.Server.Connection, sd: *SharedData, protocol: proto.Protocol) void {
    const errp = proto.Protocol.init(
        proto.Typ.ERR,
        protocol.action,
        proto.StatusCode.BAD_REQUEST,
        "server",
        sd.server.address_str,
        cmn.address_as_str(in_conn.?.address),
        @tagName(proto.StatusCode.BAD_REQUEST),
    );
    errp.dump(sd.server.log_level);
    _ = proto.transmit(in_conn.?.stream, errp);
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
