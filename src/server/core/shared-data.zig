const std = @import("std");
const Peer = @import("peer.zig").Peer;
const Server = @import("server.zig").Server;
const PeerPool = @import("peer-pool.zig").PeerPool;

// TODO: move to SharedData
pub const PeerRef = struct { peer: Peer, ref_id: usize };

pub const SharedData = struct {
    m: std.Thread.Mutex = undefined,
    should_exit: bool = undefined,
    peer_pool: *PeerPool,
    server: Server,
    pub fn setShouldExit(self: *@This(), should: bool) void {
        self.m.lock();
        defer self.m.unlock();
        self.should_exit = should;
    }
    pub fn peerPoolFindUsername(self: *@This(), username: []const u8) ?PeerRef {
        self.m.lock();
        defer self.m.unlock();
        // O(n)
        for (self.peer_pool.items, 0..) |peer, i| {
            if (std.mem.eql(u8, peer.username, username)) {
                return .{ .peer = peer, .ref_id = i };
            }
        }
        return null;
    }
    pub fn peerPoolFindId(self: *@This(), id: []const u8) ?PeerRef {
        self.m.lock();
        defer self.m.unlock();
        _ = id;
        @panic("Depricated function use peer_pool.get");
    }
    pub fn peerPoolClear(self: *@This()) void {
        self.m.lock();
        defer self.m.unlock();
        self.peer_pool.deinit();
    }
    pub fn peerPoolRemove(self: *@This(), pid: usize) void {
        self.m.lock();
        defer self.m.unlock();
        const opt_peer = self.peer_pool.peers[pid];
        if (opt_peer) |peer| {
            var mut_peer = peer;
            mut_peer.deinit();
            self.peer_pool.peers[pid] = null;
        }
    }
    pub fn peerPoolAppend(self: *@This(), peer_name: []const u8, in_conn: std.net.Server.Connection) Peer {
        self.m.lock();
        defer self.m.unlock();
        return self.peer_pool.insert(peer_name, in_conn);
    }
    pub fn markPeerForDeath(self: *@This(), peer_id: usize) void {
        self.m.lock();
        defer self.m.unlock();
        _ = peer_id;
        @panic("Depricated function");
    }
};
