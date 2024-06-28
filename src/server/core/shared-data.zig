const std = @import("std");
const pc = @import("peer.zig");
const Server = @import("server.zig").Server;

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

    pub fn peerPoolRemove(self: *@This(), pid: usize) void {
        self.m.lock();
        defer self.m.unlock();
        _ = self.peer_pool.orderedRemove(pid);
    }

    pub fn markPeerForDeath(self: *@This(), peer_id: usize) void {
        self.m.lock();
        defer self.m.unlock();
        self.peer_pool.items[peer_id].alive = false;
    }

    pub fn peerPoolAppend(self: *@This(), peer: pc.Peer) !void {
        self.m.lock();
        defer self.m.unlock();
        try self.peer_pool.append(peer);
    }
};
