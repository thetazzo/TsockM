const std = @import("std");
const aids = @import("aids");
const core = @import("../core/core.zig");
const SharedData = core.SharedData;

pub fn executor(_: ?[]const u8, cd: ?core.CommandData) void {
    // TODO: This should be client action
    const reqp = aids.Protocol.init(
        aids.Protocol.Typ.REQ,
        aids.Protocol.Act.COMM_END,
        aids.Protocol.StatusCode.OK,
        cd.?.sd.client.id,
        cd.?.sd.client.client_addr_str,
        cd.?.sd.client.server_addr_str,
        "OK",
    );
    cd.?.sd.client.sendRequestToServer(reqp); 
}

pub const COMMAND = aids.Stab.Command(core.CommandData){
    .executor = executor,
};
