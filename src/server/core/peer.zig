const std = @import("std");
const aids = @import("aids");
const cmn = aids.cmn;
const sqids = @import("sqids");
const net = std.net;
const comm = aids.v2.comm;
const mem = std.mem;
const Server = net.Server;
const print = std.debug.print;

///Generate a unique sequence of characters
///Using a Secure PRNG
pub fn generateId(allocator: std.mem.Allocator, comptime id_len: usize) []const u8 {
    const alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    var id = [_]u8{0} ** id_len;
    var rand = std.crypto.random; // secure PRNG
    for (0..id_len) |i| {
        const f = @mod(rand.int(usize), 62);
        id[i] = alphabet[f];
    }
    const id_allocd = std.fmt.allocPrint(allocator, "{s}", .{id}) catch |err| {
        std.log.err("Peer::generateId::id_allocd: {any}", .{err});
        std.posix.exit(1);
    };
    return id_allocd;
}

///Structure holding data about a connected client (peer)
///id - []const u8
///username - []const u8
///conn - net.Server.Connection
///conn_address - net.Address
///conn_address_str - []const u8
pub const Peer = struct {
    id: []const u8,
    username: []const u8,
    conn: Server.Connection = undefined,
    conn_address: net.Address = undefined,
    conn_address_str: []const u8 = "",
    alive: bool = true,
    arena: std.heap.ArenaAllocator,
    pub fn init(
        allocator: mem.Allocator,
        username: []const u8,
    ) Peer {
        var arena = std.heap.ArenaAllocator.init(allocator);
        const id = generateId(arena.allocator(), 32);
        const user_sig = generateId(arena.allocator(), 8);
        // DON'T EVER FORGET TO ALLOCATE MEMORY !!!!!!
        const username_allocd = std.fmt.allocPrint(arena.allocator(), "{s}#{s}", .{ username, user_sig }) catch |err| {
            std.log.err("Peer::init::username_allocd: {any}", .{err});
            std.posix.exit(1);
        };
        return Peer{
            .id = id,
            .username = username_allocd,
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
        testers[i] = Peer.init(str_allocator, "tester");
    }
    // test for duplicate ids
    var hits: usize = 0;
    for (0..(n - 1)) |i| { // O(n^2)
        for ((i + 1)..(n)) |j| {
            const id_hit = std.mem.eql(u8, testers[i].id, testers[j].id);
            if (id_hit) {
                std.debug.print("{s} :: {s} | {d} :: {d}\n", .{ testers[i].id, testers[j].id, i, j });
                hits += 1;
            }
            try std.testing.expectEqual(0, hits);
        }
    }
    // test for duplicate usernames
    for (0..(n - 1)) |i| {
        for ((i + 1)..(n - 1)) |j| {
            const username_hit = std.mem.eql(u8, testers[i].username, testers[j].username);
            if (username_hit) {
                std.debug.print("{s} :: {s} | {d} :: {d}\n", .{ testers[i].username, testers[j].username, i, j });
                hits += 1;
            }
            try std.testing.expectEqual(0, hits);
        }
    }
    for (0..n) |i| {
        testers[i].deinit();
    }
}
