const std = @import("std");
const ptc = @import("protocol.zig");
const mem = std.mem;
const net = std.net;
const print = std.debug.print;

fn request_connection(addr: net.Address) !void {
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
    try resp.dump();
    stream.close();
}

pub fn start() !void {
    print("Client starated\n", .{});
    const addr = try net.Address.resolveIp("127.0.0.1", 6969);
    // communication request
    _ = try request_connection(addr);
    print("Client stopped\n", .{});
}
