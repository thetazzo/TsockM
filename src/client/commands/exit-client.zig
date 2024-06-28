const std = @import("std");
const aids = @import("aids");
const core = @import("../core/core.zig");
const comm = aids.v2.comm;
const SharedData = core.SharedData;

pub fn executor(_: ?[]const u8, cd: ?core.CommandData) void {
    // TODO: This should be client action
    const reqp = comm.Protocol{
        .type = .REQ,
        .action = .COMM_END,
        .status = .OK,
        .origin = .CLIENT,
        .sender_id = cd.?.sd.client.id,
        .src_addr = cd.?.sd.client.client_addr_str,
        .dest_addr = cd.?.sd.client.server_addr_str,
        .body = "OK",
    };
    cd.?.sd.client.sendRequestToServer(reqp);
    // Collect death request response and if successful kill the client
    const resp = comm.collect(std.heap.page_allocator, cd.?.sd.client.stream) catch |err| {
        std.log.err("exit-client::executor: {any}", .{err});
        std.posix.exit(1);
    };
    if (resp.status == .OK) {
        cd.?.sd.setShouldExit(true);
    } else {
        // TODO: handle not OK case
    }
}

pub const COMMAND = aids.Stab.Command(core.CommandData){
    .executor = executor,
};
