const std = @import("std");
const aids = @import("aids");
const core = @import("../core/core.zig");
const cmn = aids.cmn;
const Protocol = aids.Protocol;
const net = std.net;
const Action = aids.Stab.Action;
const SharedData = core.SharedData;
const Peer = core.Peer;

fn collectRequest(_: net.Server.Connection, _: *SharedData, _: Protocol) void {
    std.log.err("not implemented", .{});
}

fn collectRespone(_: *SharedData, _: Protocol) void {
    std.log.err("not implemented", .{});
}

fn collectError() void {
    std.log.err("not implemented", .{});
}

fn transmitRequest(_: Protocol.TransmitionMode, _: *SharedData, _: []const u8) void {
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
