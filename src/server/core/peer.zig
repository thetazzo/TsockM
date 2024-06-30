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
///Using a Secure PRG
pub fn generateId(allocator: std.mem.Allocator, comptime id_len: usize) ![]const u8 {
    const alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    var id = [_]u8{0} ** id_len;
    var rand = std.crypto.random; // secure PRG
    for (0..id_len) |i| {
        const f = @mod(rand.int(usize), 62);
        id[i] = alphabet[f];
    }
    return try std.fmt.allocPrint(allocator, "{s}", .{id});
}

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
        const id = generateId(arena.allocator(), 32) catch |err| {
            std.log.err("Peer:init: {any}", .{err});
            std.posix.exit(1);
        };
        const user_sig = generateId(arena.allocator(), 8) catch |err| {
            std.log.err("Peer:init: {any}", .{err});
            std.posix.exit(1);
        };
        // DON'T EVER FORGET TO ALLOCATE MEMORY !!!!!!
        const username_allocd = std.fmt.allocPrint(arena.allocator(), "{s}#{s}", .{ username, user_sig }) catch |err| {
            std.log.err("Peer:init: {any}", .{err});
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
        const addr_str = std.fmt.allocPrint(self.arena.allocator(), "{any}", .{conn.address}) catch "format failed";
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

test "Peer.init1000" {
    const str_allocator = std.heap.page_allocator;
    for (0..6) |_| {
        const n = 100000;
        var testers: [n]Peer = undefined;
        for (0..n) |i| {
            testers[i] = Peer.init(str_allocator, "tester");
        }
        // test for duplicate ids
        for (0..(n - 1)) |i| {
            const res = !std.mem.eql(u8, testers[i].id, testers[i + 1].id);
            try std.testing.expect(res);
        }
        // test for duplicate usernames
        for (0..(n - 1)) |i| {
            const res = !std.mem.eql(u8, testers[i].username, testers[i + 1].username);
            try std.testing.expect(res);
        }
        for (0..n) |i| {
            testers[i].deinit();
        }
    }
}
