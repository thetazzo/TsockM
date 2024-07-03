const std = @import("std");
const Peer = @import("./peer.zig").Peer;

///Structure holding an array of connected clients (peers)
///peers - []Peer
///arena - heap.ArenaAllocator
pub const PeerPool = struct {
    peers: []Peer,
    arena: std.heap.ArenaAllocator,
    capacity: usize,
    pub fn init(allocator: std.mem.Allocator, comptime pool_cap: usize) PeerPool {
        var arena = std.heap.ArenaAllocator.init(allocator);
        const peer_pool_ptr = arena.allocator().alloc(Peer, pool_cap) catch |err| {
            std.log.err("{any}", .{err});
            std.posix.exit(1);
        };
        return PeerPool{
            .peers = peer_pool_ptr,
            .arena = arena,
            .capacity = pool_cap,
        };
    }
    pub fn deinit(self: *@This()) void {
        self.arena.deinit();
    }
};

test "PeerPool.init" {
    const test_allocator = std.heap.page_allocator;
    const pool_capacity = 10 * 1001;
    const pp = PeerPool.init(test_allocator, pool_capacity);
    try std.testing.expectEqual(pool_capacity, pp.peers.len);
}
