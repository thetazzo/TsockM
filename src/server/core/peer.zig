const std = @import("std");
const aids = @import("aids");
const core = @import("core.zig");
const cmn = aids.cmn;
const sqids = @import("sqids");
const net = std.net;
const comm = aids.v2.comm;
const mem = std.mem;
const Server = net.Server;
const print = std.debug.print;

///Structure holding data about a connected client (peer)
pub const Peer = struct {
    id: []const u8,
    username: []const u8,
    signature: []const u8,
    conn: Server.Connection = undefined,
    conn_address: net.Address = undefined,
    conn_address_str: []const u8 = "",
    alive: bool = true,
    arena: std.heap.ArenaAllocator,
    pub fn init(
        allocator: mem.Allocator,
        id: []const u8,
        username: []const u8,
    ) Peer {
        var arena = std.heap.ArenaAllocator.init(allocator);
        // DON'T EVER FORGET TO ALLOCATE MEMORY !!!!!!
        const sig_allocd = std.fmt.allocPrint(arena.allocator(), "{s}#{s}", .{ username, id }) catch |err| {
            std.log.err("Peer::init::sig_allocd: {any}", .{err});
            std.posix.exit(1);
        };
        return Peer{
            .id = id,
            .username = username,
            .signature = sig_allocd,
            .arena = arena,
        };
    }
    pub fn bindConnection(self: *@This(), conn: net.Server.Connection) void {
        self.conn = conn;
        self.conn_address = conn.address;
        const addr_str = std.fmt.allocPrint(self.arena.allocator(), "{any}", .{conn.address}) catch |err| {
            std.log.err("{any}", .{err});
            std.posix.exit(1);
        };
        self.conn_address_str = addr_str;
    }
    pub fn stream(self: @This()) net.Stream {
        return self.conn.stream;
    }
    pub fn dump(self: @This()) void {
        print("====================================\n", .{});
        print("Peer {{\n", .{});
        print("    id:        `{s}`\n", .{self.id});
        print("    username:  `{s}`\n", .{self.username});
        print("    comm_addr: `{s}`\n", .{self.conn_address_str});
        print("    alive:     `{any}`\n", .{self.alive});
        print("}}\n", .{});
        print("====================================\n", .{});
    }
    pub fn deinit(self: *@This()) void {
        self.arena.deinit();
    }
};

test "Peer.init10000" {
    const str_allocator = std.heap.page_allocator;
    const n = 10000;
    var testers: [n]Peer = undefined;
    for (0..n) |i| {
        const id = core.randomByteSequence(str_allocator, 8);
        testers[i] = Peer.init(str_allocator, id, "tester");
    }
    // test for duplicate signatures
    var hits: usize = 0;
    for (0..(n - 1)) |i| { // O(n^2)
        for ((i + 1)..(n)) |j| {
            const id_hit = std.mem.eql(u8, testers[i].signature, testers[j].signature);
            if (id_hit) {
                std.debug.print("{s} :: {s} | {d} :: {d}\n", .{ testers[i].signature, testers[j].signature, i, j });
                hits += 1;
            }
            try std.testing.expectEqual(0, hits);
        }
    }
    for (0..n) |i| {
        testers[i].deinit();
    }
}
