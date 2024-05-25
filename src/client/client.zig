const std = @import("std");
const ptc = @import("protocol.zig");
const mem = std.mem;
const net = std.net;
const print = std.debug.print;

const Client = struct {
    id: []const u8,
    server_stream: net.Stream,
};

fn request_connection(addr: net.Address) !Client {
    const stream = try net.tcpConnectToAddress(addr);
    // request connection
    const msg = "REQ::comm::-::";
    print("--------------------------------------------------\n", .{});
    print("Sending request `{s}`\n", .{msg});
    print("--------------------------------------------------\n", .{});
    _ = try stream.write(msg);
    // collect response
    var buf: [1024]u8 = undefined;
    _ = try stream.read(&buf);
    const resp_str = mem.sliceTo(&buf, 170);
    var resp = try ptc.Protocol.init(
        "",
        "",
        "",
        "",
    );
    try resp.from_str(resp_str);

    return Client{
        .id = resp.id,
        .server_stream = stream,
    };
}

fn listen_for_comms(stream: net.Stream) !void {
    while (true) {
        var msg_muf: [1054]u8 = undefined;
        _ = try stream.read(&msg_muf);
        print("Recv[]: {s}\n", .{msg_muf});
    }
}

fn read_cmd(addr: net.Address, sid: []const u8) !void {
    while (true) {
        // read for command
        var buf: [256]u8 = undefined;
        const stdin = std.io.getStdIn().reader();
        if (try stdin.readUntilDelimiterOrEof(buf[0..], '\n')) |user_input| {
            if (mem.startsWith(u8, user_input, "msg:")) {
                const msg_stream = try net.tcpConnectToAddress(addr);
                var splits = mem.split(u8, user_input, "msg:");
                _ = splits.next().?; // the `msg:` part
                const val = mem.trimLeft(u8, splits.next().?, " \n");
                const allocator = std.heap.page_allocator;
                const str = std.fmt.allocPrint(allocator, "REQ::msg::{s}::{s}", .{ sid, val }) catch "format failed";
                _ = try msg_stream.write(str);
                msg_stream.close();
            } else {
                print("Unknonw command: `{s}`\n", .{user_input});
            }
        } else {
            print("Unreachable, maybe?\n", .{});
        }
    }
}

pub fn start() !void {
    print("Client starated\n", .{});
    const addr = try net.Address.resolveIp("127.0.0.1", 6969);
    // communication request
    const client = try request_connection(addr);

    const t1 = try std.Thread.spawn(.{}, listen_for_comms, .{client.server_stream});
    const t2 = try std.Thread.spawn(.{}, read_cmd, .{ addr, client.id });
    t1.join();
    t2.join();

    print("Client stopped\n", .{});
}
