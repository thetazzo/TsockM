const std = @import("std");
const aids = @import("aids");
const core = @import("../core/core.zig");
const cmn = aids.cmn;
const Protocol = aids.Protocol;
const net = std.net;
const Command = core.Command;
const SharedData = core.SharedData;
const Peer = core.Peer;

const str_allocator = std.heap.page_allocator;

fn printCmdUsage() void {
    std.debug.print("usage: :kill <flag>\n", .{});
    std.debug.print("FLAGS:\n", .{});
    std.debug.print("    * all .......... kill all peers\n", .{});
    std.debug.print("    * <peer_id> .... id of the peer to kill\n", .{});
}

pub fn executor(cmd: []const u8, sd: *SharedData) void {
    var split = std.mem.splitBackwardsScalar(u8, cmd, ' ');
    if (split.next()) |arg| {
        if (std.mem.eql(u8, arg, cmd)) {
            std.log.err("missing command flag", .{});
            printCmdUsage();
            return;
        }
        if (std.mem.eql(u8, arg, "all")) {
            if (sd.server.Actioner.get(core.Act.COMM_END)) |act| {
                act.transmit.?.request(Protocol.TransmitionMode.BROADCAST, sd, "");
            }
        } else {
            const opt_peer_ref = core.PeerCore.peerRefFromId(sd.peer_pool, arg);
            if (opt_peer_ref) |peer_ref| {
                if (sd.server.Actioner.get(core.Act.COMM_END)) |act| {
                    const id = std.fmt.allocPrint(str_allocator, "{d}", .{peer_ref.ref_id}) catch |err| {
                        std.log.err("killPeers: {any}", .{err});
                        return;
                    };
                    defer str_allocator.free(id);
                    act.transmit.?.request(Protocol.TransmitionMode.UNICAST, sd, id);
                }
            }
        }
    }
}

pub const COMMAND = Command{
    .executor = executor,
};
