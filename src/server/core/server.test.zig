const std = @import("std");
const print = std.debug.print;
const aids = @import("aids");
const sc = @import("server.zig");
const pc = @import("peer.zig");
const SharedData = @import("shared-data.zig").SharedData;
const comm = aids.v2.comm;

const str_allocator = std.heap.page_allocator;

const hostname = "127.0.0.1";
const port = 8888;

var tmp = std.heap.GeneralPurposeAllocator(.{}){};
const gpa_allocator = tmp.allocator();
var server: sc.Server = undefined;
var user_id: []const u8 = "";
var comm_stream: std.net.Stream = undefined;

fn testingStream() !std.net.Stream {
    const addr = try std.net.Address.resolveIp(server.hostname, server.port);
    if (std.net.tcpConnectToAddress(addr)) |s| {
        return s;
    } else |err| {
        const sep = "\n------------------------------------------------------------------";
        std.log.err(
            sep ++ "\nFailed to connect to testing server. Make sure it is running!\n" ++ "expected: `127.0.0.1:8888`" ++ sep,
            .{},
        );
        return err;
    }
}

test "Server.init" {
    server = sc.Server.init(gpa_allocator, str_allocator, hostname, port, .DEV, "");
    try std.testing.expectEqualStrings("127.0.0.1:8888", server.address_str);
}

test "Server.Action.COMM" {
    comm_stream = try testingStream();
    const username = "milko";
    const reqp = comm.Protocol{
        .type = .REQ,
        .action = .COMM,
        .status = .OK,
        .origin = .SERVER,
        .sender_id = "tester",
        .src_addr = server.address_str,
        .dest_addr = server.address_str,
        .body = username,
    };
    _ = try reqp.transmit(comm_stream);
    const resp = try comm.collect(str_allocator, comm_stream);
    try std.testing.expectEqual(comm.Typ.RES, resp.type);
    try std.testing.expectEqual(comm.Act.COMM, resp.action);
    try std.testing.expectEqual(comm.Status.OK, resp.status);
    var splits = std.mem.splitScalar(u8, resp.body, '|');
    user_id = splits.next().?;
    var unns = std.mem.splitScalar(u8, splits.next().?, '#');
    const og_name = unns.first();
    try std.testing.expectEqualStrings(username, og_name);
}

test "Server.Action.MSG" {
    const stream = try testingStream();
    const reqp = comm.Protocol{
        .type = .REQ,
        .action = .MSG,
        .status = .OK,
        .origin = .SERVER,
        .sender_id = user_id,
        .src_addr = server.address_str,
        .dest_addr = server.address_str,
        .body = "Ojla",
    };
    _ = try reqp.transmit(stream);
    const resp = try comm.collect(str_allocator, comm_stream);
    try std.testing.expectEqual(comm.Typ.RES, resp.type);
    try std.testing.expectEqual(comm.Act.MSG, resp.action);
    try std.testing.expectEqual(comm.Status.OK, resp.status);
}

fn timeout() !void {
    std.time.sleep(1000000000 * 2);
    std.log.err("fuck you time", .{});
}

test "Server.Action.GET_PEER" {
    const stream = try testingStream();
    const reqp = comm.Protocol{
        .type = .REQ,
        .action = .GET_PEER,
        .status = .OK,
        .origin = .SERVER,
        .sender_id = user_id,
        .src_addr = server.address_str,
        .dest_addr = server.address_str,
        .body = user_id,
    };
    _ = try reqp.transmit(stream);
    const resp = try comm.collect(str_allocator, comm_stream);
    try std.testing.expectEqual(comm.Typ.RES, resp.type);
    try std.testing.expectEqual(comm.Act.GET_PEER, resp.action);
    try std.testing.expectEqual(comm.Status.OK, resp.status);
    _ = try std.Thread.spawn(.{}, timeout, .{});
}

test "Server.Action.GET_PEER.notFound" {
    const stream = try testingStream();
    const reqp = comm.Protocol{
        .type = .REQ,
        .action = .GET_PEER,
        .status = .OK,
        .origin = .SERVER,
        .sender_id = user_id,
        .src_addr = server.address_str,
        .dest_addr = server.address_str,
        .body = "6942",
    };
    _ = try reqp.transmit(stream);
    const resp = try comm.collect(str_allocator, comm_stream);
    try std.testing.expectEqual(comm.Typ.ERR, resp.type);
    try std.testing.expectEqual(comm.Act.GET_PEER, resp.action);
    try std.testing.expectEqual(comm.Status.NOT_FOUND, resp.status);
}

// TODO: NTFY-KILL
// TODO: COMM-END
