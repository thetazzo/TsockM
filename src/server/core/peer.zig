const std = @import("std");
const aids = @import("aids");
const cmn = aids.cmn;
const sqids = @import("sqids");
const net = std.net;
const comm = aids.v2.comm;
const mem = std.mem;
const Server = net.Server;
const print = std.debug.print;

pub const Peer = struct {
    pub const PEER_ID = []const u8;
    pub const PEER_USERNAME = []const u8;
    conn: Server.Connection,
    id: PEER_ID,
    username: PEER_USERNAME = "", // TODO: why do i allow empty username?
    alive: bool = true,

    pub fn init(conn: Server.Connection, id: PEER_ID) @This() {
        // TODO: check for peer.id collisions
        return @This(){
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

    pub fn dump(self: @This()) void {
        print("------------------------------------\n", .{});
        print("Peer {{\n", .{});
        print("    id: `{s}`\n", .{self.id});
        print("    username: `{s}`\n", .{self.username});
        print("    comm_addr: `{any}`\n", .{self.commAddress()});
        print("    alive: `{any}`\n", .{self.alive});
        print("}}\n", .{});
        print("------------------------------------\n", .{});
    }
    // TODO: replace with init
    pub fn construct(
        allocator: mem.Allocator,
        conn: net.Server.Connection,
        protocol: comm.Protocol,
    ) @This() {
        var rand = std.rand.DefaultPrng.init(@as(u64, @bitCast(std.time.milliTimestamp())));
        const s = sqids.Sqids.init(std.heap.page_allocator, .{ .min_length = 10 }) catch |err| {
            std.log.warn("{any}", .{err});
            std.posix.exit(1);
        };
        const id = s.encode(&.{ rand.random().int(u64), rand.random().int(u64), rand.random().int(u64) }) catch |err| {
            std.log.warn("{any}", .{err});
            std.posix.exit(1);
        };
        var peer = @This().init(conn, id);
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
};

pub const PeerRef = struct { peer: Peer, ref_id: usize };

pub fn peerRefFromId(peer_pool: *std.ArrayList(Peer), id: Peer.PEER_ID) ?PeerRef {
    // O(n)
    for (peer_pool.items, 0..) |peer, i| {
        if (mem.eql(u8, peer.id, id)) {
            return .{ .peer = peer, .ref_id = i };
        }
    }
    return null;
}

pub fn peerRefFromUsername(peer_pool: *std.ArrayList(Peer), username: []const u8) ?PeerRef {
    // O(n)
    for (peer_pool.items, 0..) |peer, i| {
        if (mem.eql(u8, peer.username, username)) {
            return .{ .peer = peer, .ref_id = i };
        }
    }
    return null;
}
