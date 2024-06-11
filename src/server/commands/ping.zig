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
    std.debug.print("usage: :ping <flag>\n", .{});
    std.debug.print("FLAGS:\n", .{});
    std.debug.print("    * all .......... ping all peers\n", .{});
    std.debug.print("    * <peer_id> .... id of the peer to ping\n", .{});
}

pub fn executor(cmd: []const u8, sd: *SharedData) void {
    var split = std.mem.splitBackwardsScalar(u8, cmd, ' ');
    if (split.next()) |arg| {
        if (std.mem.eql(u8, arg, cmd)) {
            std.log.err("missing flag", .{});
            printCmdUsage();
            return;
        }
        // TODO: connecton to server actions
        if (std.mem.eql(u8, arg, "all")) {
            for (sd.peer_pool.items, 0..) |peer, pid| {
                const reqp = Protocol{
                    .type = Protocol.Typ.REQ, // type
                    .action = Protocol.Act.COMM, // action
                    .status_code = Protocol.StatusCode.OK, // status_code
                    .sender_id = "server", // sender_id
                    .src = sd.server.address_str, // src_address
                    .dst = peer.commAddressAsStr(), // dst address
                    .body = "check?", // body
                };
                reqp.dump(aids.Logging.Level.DEV);
                // TODO: I don't know why but i must send 2 requests to determine the status of the stream
                _ = Protocol.transmit(peer.stream(), reqp);
                const status = Protocol.transmit(peer.stream(), reqp);
                if (status == 1) {
                    // TODO: Put htis into sd ??
                    sd.peer_pool.items[pid].alive = false;
                } 
            }
        } else {
            var found: bool = false;
            for (sd.peer_pool.items, 0..) |peer, pid| {
                if (std.mem.eql(u8, peer.id, arg)) {
                    const reqp = Protocol{
                        .type = Protocol.Typ.REQ, // type
                        .action = Protocol.Act.COMM, // action
                        .status_code = Protocol.StatusCode.OK, // status_code
                        .sender_id = "server", // sender_id
                        .src = sd.server.address_str, // src_address
                        .dst = peer.commAddressAsStr(), // dst address
                        .body = "check?", // body
                    };
                    reqp.dump(aids.Logging.Level.DEV);
                    // TODO: I don't know why but i must send 2 requests to determine the status of the stream
                    _ = Protocol.transmit(peer.stream(), reqp);
                    const status = Protocol.transmit(peer.stream(), reqp);
                    if (status == 1) {
                        // TODO: Put htis into sd ??
                        sd.peer_pool.items[pid].alive = false;
                    } 
                    found = true;
                }
            }
            if (!found) {
                std.debug.print("Peer with id `{s}` was not found!\n", .{arg});
            }
        }
    }
}

pub const COMMAND = Command{
    .executor = executor,
};
