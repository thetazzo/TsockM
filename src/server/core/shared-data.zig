const std = @import("std");
const pc = @import("peer.zig");
const Server = @import("core.zig").Server;

pub const SharedData = struct {
    m: std.Thread.Mutex = undefined,
    should_exit: bool = undefined,
    peer_pool: *std.ArrayList(pc.Peer) = undefined,
    server: Server,

    pub fn setShouldExit(self: *@This(), should: bool) void {
        self.m.lock();
        defer self.m.unlock();
        self.should_exit = should;
    }

    pub fn clearPeerPool(self: *@This()) void {
        self.m.lock();
        defer self.m.unlock();
        self.peer_pool.clearAndFree();
    }

    pub fn peerRemove(self: *@This(), pid: usize) void {
        self.m.lock();
        defer self.m.unlock();
        _ = self.peer_pool.orderedRemove(pid);
    }

    pub fn removePeerFromPool(self: *@This(), peer_ref: pc.PeerRef) void {
        self.m.lock();
        defer self.m.unlock();
        self.peer_pool.items[peer_ref.ref_id].alive = false;
        _ = self.peer_pool.orderedRemove(peer_ref.ref_id);
    }

    pub fn peerPoolAppend(self: *@This(), peer: pc.Peer) !void {
        self.m.lock();
        defer self.m.unlock();
        try self.peer_pool.append(peer);
    }
};
