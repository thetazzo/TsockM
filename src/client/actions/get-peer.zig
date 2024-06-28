const std = @import("std");
const aids = @import("aids");
const core = @import("../core/core.zig");
const net = std.net;
const comm = aids.v2.comm;
const Action = aids.Stab.Action;
const SharedData = core.SharedData;

fn collectRequest(in_conn: ?net.Server.Connection, sd: *SharedData, protocol: comm.Protocol) void {
    _ = in_conn;
    _ = sd;
    _ = protocol;
    std.log.err("not implemented", .{});
}

fn collectRespone(sd: *SharedData, protocol: comm.Protocol) void {
    _ = sd;
    _ = protocol;
    std.log.err("not implemented", .{});
}

fn collectError(_: *SharedData) void {
    std.log.err("not implemented", .{});
}

fn transmitRequest(mode: comm.TransmitionMode, sd: *SharedData, sender_id: []const u8) void {
    switch (mode) {
        .UNICAST => {
            const reqp = comm.Protocol{
                .type = .REQ, // type
                .action = .GET_PEER, // action
                .status = .OK, // status code
                .origin = .CLIENT,
                .sender_id = sd.client.id, // sender id
                .src_addr = sd.client.client_addr_str, // src address
                .dest_addr = sd.client.server_addr_str, // destination address
                .body = sender_id, //body
            };
            sd.client.sendRequestToServer(reqp);
        },
        .BROADCAST => {
            std.log.err("not implemented", .{});
            std.posix.exit(1);
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
