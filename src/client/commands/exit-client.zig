const std = @import("std");
const aids = @import("aids");
const core = @import("../core/core.zig");
const SharedData = core.SharedData;

pub fn executor(_: ?[]const u8, sd: ?*SharedData) void {
    // TODO: This should be client action
    const reqp = aids.Protocol.init(
        aids.Protocol.Typ.REQ,
        aids.Protocol.Act.COMM_END,
        aids.Protocol.StatusCode.OK,
        sd.?.client.id,
        sd.?.client.client_addr_str,
        sd.?.client.server_addr_str,
        "OK",
    );
    sd.?.client.sendRequestToServer(reqp); 
}

pub const COMMAND = aids.Stab.Command(SharedData){
    .executor = executor,
};
