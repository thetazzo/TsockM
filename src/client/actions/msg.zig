const std = @import("std");
const aids = @import("aids");
const ui = @import("../ui/ui.zig");
const core = @import("../core/core.zig");
const ClientAction = @import("actions.zig");
const Message = @import("../ui/display.zig").Message;
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
    // TODO: MSG client action
    if (protocol.status_code == Protocol.StatusCode.OK) {
        ClientAction.GET_PEER.transmit.?.request(aids.Protocol.TransmitionMode.UNICAST, sd, protocol.sender_id);
        // collect GET_PEER response
        // TODO: maybe collect* functions should return the protocol they collected?
        // TODO: GET_PEER.collect.response
        const collocator = std.heap.page_allocator;
        const np = Protocol.collect(collocator, sd.client.stream) catch |err| {
            std.log.err("actions::msg::collectRespose: {any}", .{err});
            std.posix.exit(1);
        };
        np.dump(sd.client.log_level);

        var un_spl = std.mem.split(u8, np.body, "#");
        const unn = un_spl.next().?; // user name
        // TODO: this is relevant for the terminal implementation
        //const unh = un_spl.next().?; // username hash
        // print recieved message
        //const msg_text = try std.fmt.allocPrint(
        //    str_allocator,
        //    "{s}" ++ tclr.paint_hex("#555555", "#{s}") ++ ": {s}\n",
        //    .{ unn, unh, protocol.body }
        //);
        const msg_text = std.fmt.allocPrint(collocator, "{s}", .{ protocol.body }) catch |err| {
            std.log.err("actions::msg::collectrespose: {any}", .{err});
            std.posix.exit(1);
        };

        const message = ui.Display.Message{ .author=unn, .text = msg_text };
        sd.pushMessage(message) catch |err| {
            std.log.err("actions::msg::collectrespose: {any}", .{err});
            std.posix.exit(1);
        };
    } else {
        protocol.dump(sd.client.log_level);
    }
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

    const baked_msg = std.fmt.allocPrint(std.heap.page_allocator, "{s}", .{msg}) catch |err| {
        std.log.err("`allocPrint`: {any}", .{err});
        std.posix.exit(1);
    };
    var un_spl = std.mem.split(u8, sd.client.username, "#");
    const unn = un_spl.next().?; // user name
    //const unh = un_spl.next().?; // username hash
    const message = ui.Display.Message{
        .author=unn,
        .text=baked_msg,
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
