const std = @import("std");
const aids = @import("aids");
const core = @import("../core/core.zig");
const cmn = aids.cmn;
const Protocol = aids.Protocol;
const net = std.net;
const Action = aids.Stab.Action;
const SharedData = core.SharedData;

fn collectRequest(_: ?net.Server.Connection, _: *SharedData, _: Protocol) void {
    std.log.err("`bad-request::collectRequest` action not implemented", .{});
}

fn collectRespone(sd: *SharedData, protocol: Protocol) void {
    _ = sd;
    _ = protocol;
    std.log.err("`bad-request::collectRespone` action not implemented", .{});
}

/// Happens when server is terminated
fn collectError(sd: *SharedData) void {
    sd.closeConnection();
}

fn transmitRequest(mode: Protocol.TransmitionMode, sd: *SharedData, _: []const u8) void {
    _ = mode;
    _ = sd;
    std.log.err("`bad-request::transmitRequest` action not implemented", .{});
}

fn transmitRespone() void {
    std.log.err("`bad-request::transmitRespone` action not implemented", .{});
}

fn transmitError() void {
    std.log.err("`bad-request::transmitError` action not implemented", .{});
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
