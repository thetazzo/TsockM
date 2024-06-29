const std = @import("std");
const aids = @import("aids");
const cmn = aids.cmn;
const sqids = @import("sqids");
const net = std.net;
const comm = aids.v2.comm;
const mem = std.mem;
const Server = net.Server;
const print = std.debug.print;

/// Generates a randomized sequence of characters using `Sqids` as a generator
fn generateRadomId(generator: sqids.Sqids) []const u8 {
    var rand = std.rand.DefaultPrng.init(@as(u64, @bitCast(std.time.milliTimestamp())));
    const id = generator.encode(&.{
        rand.random().int(u64),
        rand.random().int(u64),
        rand.random().int(u64),
    }) catch |err| {
        std.log.err("server::core::peer::generateRandomId: {any}", .{err});
        std.posix.exit(1);
    };
    return id;
}

pub const Peer = struct {
    allocator: std.mem.Allocator, // used in deinit
    id: []const u8,
    username: []const u8,
    conn: Server.Connection = undefined,
    conn_address: net.Address = undefined,
    conn_address_str: []const u8 = "",
    alive: bool = true,
    pub fn init(
        allocator: mem.Allocator,
        username: []const u8,
    ) Peer {
        const generator = sqids.Sqids.init(allocator, .{ .min_length = 10 }) catch |err| {
            std.log.warn("{any}", .{err});
            std.posix.exit(1);
        };
        defer generator.deinit();
        const id = generateRadomId(generator);
        const user_sig = generateRadomId(generator);
        // DON'T EVER FORGET TO ALLOCATE MEMORY !!!!!!
        const aun = std.fmt.allocPrint(allocator, "{s}#{s}", .{ username, user_sig }) catch "format failed";
        return Peer{
            .id = id,
            .username = aun,
            .allocator = allocator,
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
        _ = self;
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
