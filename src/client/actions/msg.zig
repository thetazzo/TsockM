const std = @import("std");
const aids = @import("aids");
const ui = @import("../ui/ui.zig");
const core = @import("../core/core.zig");
const ClientAction = @import("actions.zig");
const Message = @import("../ui/display.zig").Message;
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
    // TODO: MSG client action
    if (protocol.status == .OK) {
        ClientAction.GET_PEER.transmit.?.request(comm.TransmitionMode.UNICAST, sd, protocol.sender_id);
        // collect GET_PEER response
        // TODO: maybe collect* functions should return the protocol they collected?
        // TODO: GET_PEER.collect.response
        const collocator = std.heap.page_allocator;
        const np = comm.collect(collocator, sd.client.stream) catch |err| {
            std.log.err("actions::msg::collectRespose: {any}", .{err});
            std.posix.exit(1);
        };
        np.dump(sd.client.log_level);

        var un_spl = std.mem.split(u8, np.body, "#");
        const username = un_spl.next().?; // user name
        // TODO: this is relevant for the terminal implementation
        //const unh = un_spl.next().?; // username hash
        // print recieved message
        //const msg_text = try std.fmt.allocPrint(
        //    str_allocator,
        //    "{s}" ++ tclr.paint_hex("#555555", "#{s}") ++ ": {s}\n",
        //    .{ username, unh, protocol.body }
        //);
        const msg_text = std.fmt.allocPrint(collocator, "{s}", .{protocol.body}) catch |err| {
            std.log.err("actions::msg::collectrespose: {any}", .{err});
            std.posix.exit(1);
        };
        // TODO: this disabled users from sending `OK` messages this must be handled differently
        if (!std.mem.eql(u8, msg_text, "OK")) {
            const message = ui.Display.Message{ .author = username, .text = msg_text };
            sd.pushMessage(message) catch |err| {
                std.log.err("actions::msg::collectrespose: {any}", .{err});
                std.posix.exit(1);
            };
        }
    } else {
        protocol.dump(sd.client.log_level);
    }
}

fn collectError(_: *SharedData) void {
    std.log.err("not implemented", .{});
}

fn transmitRequest(_: comm.TransmitionMode, sd: *SharedData, msg: []const u8) void {
    // handle sending a message
    const reqp = comm.Protocol{
        .type = .REQ,
        .action = .MSG,
        .origin = .CLIENT,
        .status = .OK,
        .sender_id = sd.client.id,
        .src_addr = sd.client.client_addr_str,
        .dest_addr = sd.client.server_addr_str,
        .body = msg,
    };
    sd.client.sendRequestToServer(reqp);

    const baked_msg = std.fmt.allocPrint(std.heap.page_allocator, "{s}", .{msg}) catch |err| {
        std.log.err("`allocPrint`: {any}", .{err});
        std.posix.exit(1);
    };
    var un_spl = std.mem.split(u8, sd.client.username, "#");
    const username = un_spl.next().?; // user name
    //const unh = un_spl.next().?; // username hash
    const message = ui.Display.Message{
        .author = username,
        .text = baked_msg,
    };
    sd.pushMessage(message) catch |err| {
        std.log.err("`message_display`: {any}", .{err});
        std.posix.exit(1);
    };
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
