const std = @import("std");
const net = std.net;
const Connection = std.net.Server.Connection;
const mem = std.mem;
const print = std.debug.print;
const ptc = @import("protocol.zig");

const SILENT = false;

fn create_localhost_server(port: u16) !net.Server {
    const localhost = try net.Address.resolveIp("127.0.0.1", port);
    print("Listening on `127.0.0.1:{d}`\n", .{port});
    return localhost.listen(.{});
}

fn from_connection(conn: Connection, p: *ptc.Protocol) !void {
    const stream = conn.stream;
    var buf: [256]u8 = undefined;
    _ = try stream.read(&buf);
    const req = mem.sliceTo(&buf, 170);
    if (!SILENT) {
        print("Incomming request `{s}`\n", .{req});
    }
    try p.from_str(req);
}

fn establish_conn(peer_pool: *std.ArrayList(Connection), conn: Connection) !void {
    const conn_stream = conn.stream;
    _ = try peer_pool.append(conn);
    var idbuf: [256]u8 = undefined;
    const id = try std.fmt.bufPrint(&idbuf, "{d}", .{peer_pool.items.len});
    const resp = ptc.Protocol{
        .type = "RES",
        .action = "comm",
        .id = id,
        .body = "",
    };
    if (!SILENT) {
        try resp.dump();
    }
    const tmp = try resp.protocol_to_str();
    _ = try conn_stream.write(tmp);
}

pub fn start() !void {
    print("Server started\n", .{});
    // server creation
    var server = try create_localhost_server(6969);
    defer server.deinit();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    // List of all connected clients (their message reading streams)
    var peer_pool = std.ArrayList(net.Server.Connection).init(allocator);
    defer peer_pool.deinit();

    // handle incomming client requests (connections)
    // TODO: A better infinite loop handling using delta time
    while (true) {
        const conn = try server.accept();
        // Construct protocol from connection
        var prot = try ptc.Protocol.init("", "", "", "");
        _ = try from_connection(conn, &prot);
        try prot.dump();
        if (mem.eql(u8, prot.type, "REQ")) {
            if (mem.eql(u8, prot.action, "comm")) {
                try establish_conn(&peer_pool, conn);
            }
        }
        // Determine what to do
        //     - REQ::cmp  -> establish_comm(peer_pool, prot)
        //     - REQ::msg  -> forward_message(prot)
        //     - REQ::exit -> kill peer(prot)
        // try handle_connection(&peer_pool, conn);
    }

    // Close all peers
    for (peer_pool.items[0..]) |peer| {
        peer.stream.close();
    }

    print("Server closed\n", .{});
}
