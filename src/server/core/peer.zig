const std = @import("std");
const aids = @import("aids");
const cmn = aids.cmn;
const sqids = @import("sqids");
const net = std.net;
const comm = aids.v2.comm;
const mem = std.mem;
const Server = net.Server;
const print = std.debug.print;

pub fn generateId(id_len: usize, string: *std.ArrayList(u8)) ![]const u8 {
    const alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    var rand = std.crypto.random;
    for (0..id_len) |_| {
        const f = @mod(rand.int(usize), 62);
        try string.append(alphabet[f]);
    }
    return string.items;
}

pub const Peer = struct {
    allocator: std.mem.Allocator, // used in deinit
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
        const str_alloc = std.heap.page_allocator;
        var id_sa = std.ArrayList(u8).init(str_alloc);
        const arena = std.heap.ArenaAllocator.init(str_alloc);
        const id = generateId(32, &id_sa) catch |err| {
            std.log.err("Peer:init: {any}", .{err});
            std.posix.exit(1);
        };
        var un_sa = std.ArrayList(u8).init(str_alloc);
        const user_sig = generateId(8, &un_sa) catch |err| {
            std.log.err("Peer:init: {any}", .{err});
            std.posix.exit(1);
        };
        // DON'T EVER FORGET TO ALLOCATE MEMORY !!!!!!
        const aun = std.fmt.allocPrint(allocator, "{s}#{s}", .{ username, user_sig }) catch "format failed";
        return Peer{
            .id = id,
            .username = aun,
            .allocator = allocator,
            .arena = arena,
        };
    }
    pub fn bindConnection(self: *@This(), conn: net.Server.Connection) void {
        self.conn = conn;
        self.conn_address = conn.address;
        const addr_str = std.fmt.allocPrint(self.allocator, "{any}", .{conn.address}) catch "format failed";
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
    const n = 1000;
    var testers: [n]Peer = undefined;
    for (0..n) |i| {
        testers[i] = Peer.init(str_allocator, "tester");
        std.time.sleep(200000); // because if two peers get created at exactly the same time their IDs are generated equal // TODO: check for ID collisions
    }
    for (0..(n - 1)) |i| {
        const res = !std.mem.eql(u8, testers[i].username, testers[i + 1].username);
        try std.testing.expect(res);
    }
}
