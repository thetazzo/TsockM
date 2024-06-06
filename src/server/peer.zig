const std = @import("std");
const cmn = @import("cmn");
const ptc = @import("ptc");
const sqids = @import("sqids");
const net = std.net;
const mem = std.mem;
const Server = net.Server;
const print = std.debug.print;

const PEER_ID = []const u8;

pub const Peer = struct {
    conn: Server.Connection,
    id: PEER_ID,
    username: PEER_ID = "",
    alive: bool = true,
    pub fn init(conn: Server.Connection, id: PEER_ID) Peer {
        // TODO: check for peer.id collisions
        return Peer{
            .id = id,
            .conn = conn,
        };
    }
    pub fn stream(self: @This()) net.Stream {
        return self.conn.stream;
    }
    pub fn commAddress(self: @This()) net.Address {
        return self.conn.address;
    }
    pub fn commAddressAsStr(self: @This()) []const u8 {
        return cmn.address_as_str(self.conn.address);
    }
};

pub fn dump(p: Peer) void {
    print("------------------------------------\n", .{});
    print("Peer {{\n", .{});
    print("    id: `{s}`\n", .{p.id});
    print("    username: `{s}`\n", .{p.username});
    print("    comm_addr: `{any}`\n", .{p.commAddress()});
    print("    alive: `{any}`\n", .{p.alive});
    print("}}\n", .{});
    print("------------------------------------\n", .{});
}

const PeerRef = struct { peer: Peer, ref_id: usize };

pub fn findRef(peer_pool: *std.ArrayList(Peer), id: PEER_ID) ?PeerRef {
    // O(n)
    for (peer_pool.items, 0..) |peer, i| {
        if (mem.eql(u8, peer.id, id)) {
            return .{ .peer = peer, .ref_id = i };
        }
    }
    return null;
}

pub fn findUsername(peer_pool: *std.ArrayList(Peer), un: []const u8) ?PeerRef {
    // O(n)
    for (peer_pool.items, 0..) |peer, i| {
        if (mem.eql(u8, peer.username, un)) {
            return .{ .peer = peer, .ref_id = i };
        }
    }
    return null;
}

pub fn construct(
    allocator: mem.Allocator,
    conn: net.Server.Connection,
    protocol: ptc.Protocol,
) Peer {
    var rand = std.rand.DefaultPrng.init(@as(u64, @bitCast(std.time.milliTimestamp())));
    const s = sqids.Sqids.init(std.heap.page_allocator, .{ .min_length = 10 }) catch |err| {
        std.log.warn("{any}", .{err});
        std.posix.exit(1);
    };
    const id = s.encode(&.{ rand.random().int(u64), rand.random().int(u64), rand.random().int(u64) }) catch |err| {
        std.log.warn("{any}", .{err});
        std.posix.exit(1);
    };
    var peer = Peer.init(conn, id);
    const user_sig = s.encode(&.{ rand.random().int(u8), rand.random().int(u8), rand.random().int(u8) }) catch |err| {
        std.log.warn("{any}", .{err});
        std.posix.exit(1);
    };
    // DON'T EVER FORGET TO ALLOCATE MEMORY !!!!!!
    // TODO: try fmn.comptimeAlloc
    const aun = std.fmt.allocPrint(allocator, "{s}#{s}", .{ protocol.body, user_sig }) catch "format failed";
    peer.username = aun;
    dump(peer);
    return peer;
}
