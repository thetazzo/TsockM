const std = @import("std");
const ptc = @import("protocol.zig");
const mem = std.mem;
const net = std.net;
const print = std.debug.print;

var SILENT = true;

const Client = struct {
    id: []const u8,
    server_stream: net.Stream,

    pub fn dump(self: @This()) void {
        print("------------------------------------\n", .{});
        print("Client {{\n", .{});
        print("    id: `{s}`\n", .{self.id});
        print("}}\n", .{});
        print("------------------------------------\n", .{});
    }
};

fn request_connection(addr: net.Address) !Client {
    const stream = try net.tcpConnectToAddress(addr);
    // request connection
    const reqp = try ptc.Protocol.init("REQ", "comm", "-", "").as_str(); // request communication protocol
    _ = try stream.write(reqp); // send request

    // collect response
    var buf: [1024]u8 = undefined;
    _ = try stream.read(&buf);
    const resp_str = mem.sliceTo(&buf, 170);

    // construct protocol from response string
    const resp = ptc.protocol_from_str(resp_str);
    if (!SILENT) {
        resp.dump();
    }

    // construct the clint
    const c = Client{
        .id = resp.id,
        .server_stream = stream,
    };
    c.dump(); // print the client

    return c;
}

fn listen_for_comms(stream: net.Stream) !void {
    while (true) {
        var msg_muf: [1054]u8 = undefined;
        _ = try stream.read(&msg_muf);
        print("{s}\n", .{msg_muf});
    }
}

fn read_cmd(addr: net.Address, sid: []const u8) !void {
    while (true) {
        // read for command
        var buf: [256]u8 = undefined;
        const stdin = std.io.getStdIn().reader();
        if (try stdin.readUntilDelimiterOrEof(buf[0..], '\n')) |user_input| {
            // Handle different commands
            if (mem.startsWith(u8, user_input, "msg:")) {
                // Messaging command
                // request a tcp socket for sending a message
                const msg_stream = try net.tcpConnectToAddress(addr);

                // parse message from cmd
                var splits = mem.split(u8, user_input, "msg:");
                _ = splits.next().?; // the `msg:` part
                const val = mem.trimLeft(u8, splits.next().?, " \n");

                // construct message protocol
                const msgp = try ptc.Protocol.init("REQ", "msg", sid, val).as_str(); // create message protocol string

                // send message protocol to server
                _ = try msg_stream.write(msgp);

                // close messaging socket
                msg_stream.close();
            } else if (mem.startsWith(u8, user_input, "help")) {
                print("COMMANDS:\n", .{});
                print("    * :msg <message> .... boradcast the message to all users\n", .{});
            } else {
                print("Unknown command: `{s}`\n", .{user_input});
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
