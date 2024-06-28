const std = @import("std");
const aids = @import("aids");
const cmn = aids.cmn;
const sqids = @import("sqids");
const net = std.net;
const comm = aids.v2.comm;
const mem = std.mem;
const Server = net.Server;
const print = std.debug.print;

pub const Peer = struct {
    allocator: std.mem.Allocator, // used in deinit
    conn: Server.Connection,
    id: []const u8,
    username: []const u8,
    alive: bool = true,
    pub fn stream(self: @This()) net.Stream {
        return self.conn.stream;
    }
    pub fn commAddress(self: @This()) net.Address {
        return self.conn.address;
    }
    pub fn commAddressAsStr(self: @This()) []const u8 {
        return cmn.address_as_str(self.conn.address);
    }
    pub fn dump(self: @This()) void {
        print("------------------------------------\n", .{});
        print("Peer {{\n", .{});
        print("    id: `{s}`\n", .{self.id});
        print("    username: `{s}`\n", .{self.username});
        print("    comm_addr: `{any}`\n", .{self.commAddress()});
        print("    alive: `{any}`\n", .{self.alive});
        print("}}\n", .{});
        print("------------------------------------\n", .{});
    }
    pub fn init(
        allocator: mem.Allocator,
        conn: net.Server.Connection,
        protocol: comm.Protocol,
    ) @This() {
        var rand = std.rand.DefaultPrng.init(@as(u64, @bitCast(std.time.milliTimestamp())));
        const s = sqids.Sqids.init(allocator, .{ .min_length = 10 }) catch |err| {
            std.log.warn("{any}", .{err});
            std.posix.exit(1);
        };
        const id = s.encode(&.{ rand.random().int(u64), rand.random().int(u64), rand.random().int(u64) }) catch |err| {
            std.log.warn("{any}", .{err});
            std.posix.exit(1);
        };
        const user_sig = s.encode(&.{ rand.random().int(u8), rand.random().int(u8), rand.random().int(u8) }) catch |err| {
            std.log.warn("{any}", .{err});
            std.posix.exit(1);
        };
        // DON'T EVER FORGET TO ALLOCATE MEMORY !!!!!!
        // TODO: Peer deinit
        const aun = std.fmt.allocPrint(allocator, "{s}#{s}", .{ protocol.body, user_sig }) catch "format failed";
        return Peer{
            .conn = conn,
            .id = id,
            .username = aun,
            .allocator = allocator,
        };
    }
    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.username);
    }
};
