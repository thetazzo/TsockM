const std = @import("std");
const core = @import("core.zig");
const Peer = @import("./peer.zig").Peer;

/// Hashing function used for hashing peer ids
fn hasher(peer_id: []const u8) usize {
    const g = 31; // magic prime number
    var hash: usize = 0;
    for (peer_id) |char| {
        hash = g * hash + char; // the java implementation of hashcode xD
    }
    return hash;
}

///Structure for storing an array of connected clients (peers) with unique ids
pub const PeerPool = struct {
    peers: []?Peer,
    arena: std.heap.ArenaAllocator,
    capacity: usize,
    pub fn init(allocator: std.mem.Allocator, comptime pool_cap: usize) PeerPool {
        var arena = std.heap.ArenaAllocator.init(allocator);
        const peer_pool_ptr = arena.allocator().alloc(?Peer, pool_cap) catch |err| {
            std.log.err("{any}", .{err});
            std.posix.exit(1);
        };
        for (0..pool_cap) |i| {
            peer_pool_ptr[i] = null;
        }
        return PeerPool{
            .peers = peer_pool_ptr,
            .arena = arena,
            .capacity = pool_cap,
        };
    }
    pub fn deinit(self: *@This()) void {
        self.arena.deinit();
    }
    ///Create a Peer instance and insert it into the peer pool where each Peer.id is generated such that they are unique and can be mapped to peer position in the pool
    pub fn insert(self: *@This(), name: []const u8, conn: std.net.Server.Connection) Peer {
        if (self.capacity == 0) {
            @panic("No more space left in the pool");
        }
        var pid = core.randomByteSequence(self.arena.allocator(), 5); // inital peer id
        var ppi = @as(usize, @intCast(@mod(hasher(pid), self.peers.len))); // index in peers array
        while (self.peers[ppi] != null) {
            // TODO: free the previously allocated id
            pid = core.randomByteSequence(self.arena.allocator(), 5);
            ppi = @as(usize, @intCast(@mod(hasher(pid), self.peers.len)));
        }
        self.capacity -= 1;
        var peer = Peer.init(
            self.arena.allocator(),
            pid,
            name,
        );
        peer.conn = conn;
        const addr_str = std.fmt.allocPrint(self.arena.allocator(), "{any}", .{conn.address}) catch |err| {
            std.log.err("{any}", .{err});
            std.posix.exit(1);
        };
        peer.conn_address_str = addr_str;
        self.peers[ppi] = peer;
        return peer;
    }
    pub fn printHead(self: @This()) void {
        for (0..10) |i| {
            const peer_opt = self.peers[i];
            if (peer_opt) |peer| {
                peer.dump();
            } else {
                std.log.warn("No peer found at index `{d}`", .{i});
            }
        }
    }
    pub fn get(self: @This(), peer_id: []const u8) ?Peer {
        const ppi = @as(usize, @intCast(@mod(hasher(peer_id), self.peers.len))); // index in peers array
        if (self.peers[ppi]) |peer| {
            return peer;
        }
        return null;
    }
};

test "PeerPool.init" {
    const test_allocator = std.heap.page_allocator;
    const pool_capacity = 10 * 1001;
    const pp = PeerPool.init(test_allocator, pool_capacity);
    try std.testing.expectEqual(pool_capacity, pp.peers.len);
}

test "PeerPool.generateID" {
    const str_allocator = std.heap.page_allocator;
    const n = 1000;
    var ids: [n][]const u8 = undefined;
    for (0..n) |i| {
        ids[i] = core.randomByteSequence(str_allocator, 5);
    }
    var collisions: usize = 0;
    // please kill me this is going to be a O(n^2)
    for (0..(n - 1)) |i| {
        for ((i + 1)..(n)) |j| {
            if (std.mem.eql(u8, ids[i], ids[j])) {
                collisions += 1;
            }
        }
    }
    try std.testing.expectEqual(0, collisions);
}

test "PeerPool.insert" {
    const test_allocator = std.heap.page_allocator;
    const pool_capacity = 10;
    var pp = PeerPool.init(test_allocator, pool_capacity);
    _ = pp.insert("SnoopyDoggy Dog");
    _ = pp.insert("Luka");
    _ = pp.insert("Mare");
    _ = pp.insert("Janko");
    _ = pp.insert("CJ");
    _ = pp.insert("Brodnik");
    _ = pp.insert("Pozar");
    _ = pp.insert("Milanic");
    _ = pp.insert("Vake");
    _ = pp.insert("Aralica");
    try std.testing.expectEqual(0, pp.capacity);
    pp.deinit();
}

test "PeerPool.getPeer" {
    const test_allocator = std.heap.page_allocator;
    const pool_capacity = 10;
    var pp = PeerPool.init(test_allocator, pool_capacity);
    // insert 10 peers
    const test_peers = [_][]const u8{
        "SnoopyDoggy Dog",
        "Luka",
        "Mare",
        "Janko",
        "CJ",
        "Brodnik",
        "Pozar",
        "Milanic",
        "Vake",
        "Aralica",
    };
    var testing_sigs: [pool_capacity][]const u8 = undefined;
    for (test_peers, 0..testing_sigs.len) |peer_name, i| {
        const peer = pp.insert(peer_name);
        testing_sigs[i] = peer.signature;
    }
    // using getPeer validate that correct peers were inserted
    for (testing_sigs, 0..testing_sigs.len) |sig, _| {
        var sig_split = std.mem.splitScalar(u8, sig, '#');
        const name = sig_split.next().?;
        const id = sig_split.next().?;
        const peer_opt = pp.get(id);
        if (peer_opt) |peer| {
            try std.testing.expectEqualStrings(name, peer.username);
        }
    }
    pp.deinit();
}

// Test insertion time of 1 milion peers, it should be around 10s :D
test "PeerPool.stressTest" {
    const test_allocator = std.heap.page_allocator;
    const pool_capacity = 1 * 1000001;
    var pp = PeerPool.init(test_allocator, pool_capacity);
    const start = try std.time.Instant.now();
    for (0..pool_capacity) |_| {
        _ = pp.insert("tester");
    }
    pp.deinit();
    const end = try std.time.Instant.now();
    const dt = end.since(start);
    try std.testing.expect((dt / std.time.ns_per_s) < 15); // expected time to be less then 15 seconds
}
