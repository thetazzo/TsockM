const std = @import("std");
const aids = @import("aids");
const core = @import("../core/core.zig");
const Message = @import("../ui/display.zig").Message;
const net = std.net;
const comm = aids.v2.comm;
const Action = aids.Stab.Action;
const SharedData = core.SharedData;

fn collectRequest(_: ?net.Server.Connection, sd: *SharedData, protocol: comm.Protocol) void {
    if (protocol.status_code == .OK) {
        sd.setShouldExit(true);
        return;
    }
}

fn collectRespone(sd: *SharedData, protocol: comm.Protocol) void {
    _ = sd;
    _ = protocol;
    // if (protocol.status_code == comm.Protocol.StatusCode.OK) {
    //     sd.setShouldExit(true);
    // }
}

fn collectError(_: *SharedData) void {
    std.log.err("not implemented", .{});
}

fn transmitRequest(_: comm.TransmitionMode, sd: *SharedData, _: []const u8) void {
    const reqp = comm.Protocol{
        .type = .REQ,
        .action = .COMM_END,
        .status_code = .OK,
        .sender_id = sd.client.id,
        .src_addr = sd.client.client_addr_str,
        .dest_addr = sd.client.server_addr_str,
        .body = "OK",
    };
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
