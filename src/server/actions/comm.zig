const std = @import("std");
const aids = @import("aids");
const core = @import("../core/core.zig");
const cmn = aids.cmn;
const net = std.net;
const comm = aids.v2.comm;
const Action = aids.Stab.Action;
const SharedData = core.SharedData;
const Peer = core.Peer;

fn collectRequest(in_conn: ?net.Server.Connection, sd: *SharedData, protocol: comm.Protocol) void {
    const addr_str = cmn.address_as_str(in_conn.?.address);
    const stream = in_conn.?.stream;

    // TODO: find a way around the allocator
    const tmp_allocator = std.heap.page_allocator;
    var peer = Peer.init(tmp_allocator, core.randomByteSequence(tmp_allocator, 8), protocol.body);
    peer.bindConnection(in_conn.?);
    const peer_str = std.fmt.allocPrint(tmp_allocator, "{s}|{s}", .{ peer.id, peer.username }) catch "format failed";
    sd.peerPoolAppend(peer) catch |err| {
        std.log.err("`comm-action::collectRequest::peerPoolAppend`: {any}", .{err});
        std.posix.exit(1);
    };
    const resp = comm.Protocol{
        .type = .RES, // type
        .action = .COMM, // action
        .status = .OK, // status code
        .origin = .SERVER,
        .sender_id = "", // sender id
        .src_addr = sd.server.address_str, // sender address
        .dest_addr = addr_str, // reciever address
        .body = peer_str, // body
    };
    resp.dump(sd.server.log_level);
    _ = resp.transmit(stream) catch 1;
}

fn collectRespone(sd: *SharedData, protocol: comm.Protocol) void {
    const opt_peer_ref = sd.peerPoolFindId(protocol.sender_id);
    if (opt_peer_ref) |peer_ref| {
        std.debug.print("peer `{s}` is alive\n", .{peer_ref.peer.username});
    } else {
        std.debug.print("Peer with id `{s}` does not exist!\n", .{protocol.sender_id});
    }
}

fn collectError(_: *SharedData) void {
    std.log.err("not implemented", .{});
}

fn transmitRequest(mode: comm.TransmitionMode, sd: *SharedData, _: []const u8) void {
    switch (mode) {
        .UNICAST => {
            std.log.err("not implemented", .{});
            unreachable;
        },
        .BROADCAST => {
            for (sd.peer_pool.items, 0..) |peer, pid| {
                const reqp = comm.Protocol{
                    .type = comm.Typ.REQ, // type
                    .action = comm.Act.COMM, // action
                    .status = comm.Status.OK, // status
                    .origin = .SERVER,
                    .sender_id = "", // sender_id
                    .src_addr = sd.server.address_str, // src_address
                    .dest_addr = peer.conn_address_str, // dst address
                    .body = "check", // body
                };
                reqp.dump(sd.server.log_level);
                // TODO: I don't know why but i must send 2 requests to determine the status of the stream
                const status = reqp.transmit(peer.stream()) catch 1;
                if (status == 1) {
                    sd.markPeerForDeath(pid);
                }
            }
        },
    }
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
