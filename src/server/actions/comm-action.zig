const std = @import("std");
const aids = @import("aids");
const core = @import("../core/core.zig");
const cmn = aids.cmn;
const Protocol = aids.Protocol;
const net = std.net;
const Action = aids.Stab.Action;
const SharedData = core.SharedData;
const Peer = core.Peer;

fn collectRequest(in_conn: ?net.Server.Connection, sd: *SharedData, protocol: Protocol) void {
    const addr_str = cmn.address_as_str(in_conn.?.address);
    const stream = in_conn.?.stream;

    // TODO: find a way around the allocator
    const tmp_allocator = std.heap.page_allocator;
    const peer = Peer.construct(tmp_allocator, in_conn.?, protocol);
    const peer_str = std.fmt.allocPrint(tmp_allocator, "{s}|{s}", .{ peer.id, peer.username }) catch "format failed";
    sd.peerPoolAppend(peer) catch |err| {
        std.log.err("`comm-action::collectRequest::peerPoolAppend`: {any}", .{err});
        std.posix.exit(1);
    };
    const resp = Protocol.init(
        Protocol.Typ.RES,       // type
        Protocol.Act.COMM,      // action
        Protocol.StatusCode.OK, // status code
        "server",               // sender id
        sd.server.address_str,  // sender address
        addr_str,               // reciever address
        peer_str,               // body
    );
    resp.dump(sd.server.log_level);
    _ = Protocol.transmit(stream, resp);
}

fn collectRespone(sd: *SharedData, protocol: Protocol) void {
    const opt_peer_ref = core.PeerCore.peerRefFromId(sd.peer_pool, protocol.sender_id);
    if (opt_peer_ref) |peer_ref| {
        std.debug.print("peer `{s}` is alive\n", .{peer_ref.peer.username});
    } else {
        std.debug.print("Peer with id `{s}` does not exist!\n", .{protocol.sender_id});
    }
}

fn collectError() void {
    std.log.err("not implemented", .{});
}

fn transmitRequest(mode: Protocol.TransmitionMode, sd: *SharedData, _: []const u8) void {
    switch (mode) {
        .UNICAST => {
            std.log.err("not implemented", .{});
            unreachable;
        },
        .BROADCAST => {
            for (sd.peer_pool.items, 0..) |peer, pid| {
                const reqp = Protocol{
                    .type = Protocol.Typ.REQ,              // type
                    .action = Protocol.Act.COMM,           // action
                    .status_code = Protocol.StatusCode.OK, // status_code
                    .sender_id = "server",                 // sender_id
                    .src = sd.server.address_str,          // src_address
                    .dst = peer.commAddressAsStr(),        // dst address
                    .body = "check",                       // body
                };
                reqp.dump(sd.server.log_level);
                // TODO: I don't know why but i must send 2 requests to determine the status of the stream
                _ = Protocol.transmit(peer.stream(), reqp);
                const status = Protocol.transmit(peer.stream(), reqp);
                // 
                if (status == 1) {
                    // TODO: Put this into sd ??
                    // TODO introduce markPeerForDeath or straight peer remove
                    sd.peer_pool.items[pid].alive = false;
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
