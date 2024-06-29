const std = @import("std");
const aids = @import("aids");
const comm = aids.v2.comm;
const core = @import("../core/core.zig");
const SharedData = core.SharedData;

const str_allocator = std.heap.page_allocator;

fn printCmdUsage() void {
    std.debug.print("usage: :kill <flag>\n", .{});
    std.debug.print("FLAGS:\n", .{});
    std.debug.print("    * all .......... kill all peers\n", .{});
    std.debug.print("    * <peer_id> .... id of the peer to kill\n", .{});
}

pub fn executor(cmd: ?[]const u8, cd: ?core.sc.CommandData) void {
    var split = std.mem.splitBackwardsScalar(u8, cmd.?, ' ');
    if (split.next()) |arg| {
        if (std.mem.eql(u8, arg, cmd.?)) {
            std.log.err("missing command flag", .{});
            printCmdUsage();
            return;
        }
        if (std.mem.eql(u8, arg, "all")) {
            if (cd.?.sd.server.Actioner.get(aids.Stab.Act.COMM_END)) |act| {
                act.transmit.?.request(comm.TransmitionMode.BROADCAST, cd.?.sd, "");
            }
        } else {
            const opt_peer_ref = cd.?.sd.peerPoolFindId(arg);
            if (opt_peer_ref) |peer_ref| {
                if (cd.?.sd.server.Actioner.get(aids.Stab.Act.COMM_END)) |act| {
                    const id = std.fmt.allocPrint(str_allocator, "{d}", .{peer_ref.ref_id}) catch |err| {
                        std.log.err("killPeers: {any}", .{err});
                        return;
                    };
                    defer str_allocator.free(id);
                    act.transmit.?.request(comm.TransmitionMode.UNICAST, cd.?.sd, id);
                }
            }
        }
    }
}

pub const COMMAND = aids.Stab.Command(core.sc.CommandData){
    .executor = executor,
};
