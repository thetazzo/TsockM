const std = @import("std");
const aids = @import("aids");
const core = @import("../core/core.zig");
const SharedData = core.SharedData;

pub fn executor(_: ?[]const u8, cd: ?core.CommandData) void {
    const username = cd.?.body;
    //const client = cd.?.sd.client;
    if (username.len > 0) {
        std.debug.print("un: `{s}`", .{username});
        std.log.err("SERVER does not support this yet", .{});
        std.posix.exit(1);
        //const reqp = aids.Protocol.init(
        //    aids.Protocol.Typ.REQ,
        //    aids.Protocol.Act.GET_PEER,
        //    aids.Protocol.StatusCode.OK,
        //    client.id,
        //    client.client_addr_str,
        //    client.server_addr_str,
        //    username,
        //);
        //client.sendRequestToServer(reqp);
    } else {
        std.log.warn("missing peer username", .{});
    }
    //send_request(client.server_addr, reqp) catch |err| {
    //    std.log.err("`send_request`: {any}", .{err});
    //    std.posix.exit(1);
    //};
    // TODO: collect response
    // TODO: print peer data to message_display
    //const message = rld.Message{
    //    .author=unn,
    //    .text=q,
    //};
    //_ = message_display.messages.append(message) catch |err| {
    //    std.log.err("`message_display`: {any}", .{err});
    //    std.posix.exit(1);
    //};
    //_ = message_box.clean();
}

pub const COMMAND = aids.Stab.Command(core.CommandData){
    .executor = executor,
};
