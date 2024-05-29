const std = @import("std");
const ptc = @import("ptc");
const cmn = @import("cmn");
const mem = std.mem;
const net = std.net;
const print = std.debug.print;

const LOG_LEVEL = ptc.LogLevel.SILENT;

const Client = struct {
    id: []const u8,
    stream: net.Stream,
    comm_addr: ptc.Addr,

    pub fn dump(self: @This()) void {
        print("------------------------------------\n", .{});
        print("Client {{\n", .{});
        print("    id: `{s}`\n", .{self.id});
        print("    comm_addr: `{s}`\n", .{self.comm_addr});
        print("}}\n", .{});
        print("------------------------------------\n", .{});
    }
};

fn print_usage() void {
    print("COMMANDS:\n", .{});
    print("    * :msg <message> .... boradcast the message to all users\n", .{});
    print("    * :exit ............. terminate the program\n", .{});
}

fn request_connection(addr: net.Address) !Client {
    const stream = try net.tcpConnectToAddress(addr);
    const dst_addr = cmn.address_to_str(addr);
    // request connection
    const reqp = ptc.Protocol.init(ptc.Typ.REQ, ptc.Act.COMM, "bebey", "client", dst_addr, "");
    reqp.dump(LOG_LEVEL);
    reqp.transmit(stream);

    // collect response
    var buf: [1024]u8 = undefined;
    _ = try stream.read(&buf);
    const resp_str = mem.sliceTo(&buf, 170);

    // construct protocol from response string
    const resp = ptc.protocol_from_str(resp_str);
    resp.dump(LOG_LEVEL);

    // construct the clint
    var c = Client{
        .id = resp.id,
        .stream = stream,
        .comm_addr = resp.dst,
    };
    c.dump(); // print the client

    return c;
}

fn listen_for_comms(client: *Client) !void {
    while (true) {
        var buf: [1054]u8 = undefined;
        const q = client.stream.read(&buf) catch 1;
        const response = mem.sliceTo(&buf, 170);

        if (q == 1) {
            std.log.warn("Terminated listener\n", .{});
            return;
        }

        if (response.len == 0) {
            continue;
        }

        print("{s}\n", .{response});
        const resp = ptc.protocol_from_str(response);
        resp.dump(LOG_LEVEL);
        if (resp.is_response()) {
            if (resp.is_action(ptc.Act.COMM_END)) {
                if (mem.eql(u8, resp.id, "200")) {
                    //client.stream.close();
                    break;
                }
            }
        } else if (resp.type == ptc.Typ.ERR) {
            //client.stream.close();
            resp.dump(LOG_LEVEL);
        }
    }
    print("end me\n", .{});
}

fn read_cmd(addr: net.Address, client: *Client) !void {
    const addr_str = cmn.address_to_str(addr);
    while (true) {
        // read for command
        var buf: [256]u8 = undefined;
        const stdin = std.io.getStdIn().reader();
        if (try stdin.readUntilDelimiterOrEof(buf[0..], '\n')) |user_input| {
            // Handle different commands
            if (mem.startsWith(u8, user_input, ":msg")) {
                // Messaging command
                // request a tcp socket for sending a message
                const msg_stream = try net.tcpConnectToAddress(addr);
                defer msg_stream.close();

                // parse message from cmd
                var splits = mem.split(u8, user_input, ":msg");
                _ = splits.next().?; // the `:msg` part
                const val = mem.trimLeft(u8, splits.next().?, " \n");

                // construct message protocol
                const msgp = ptc.Protocol.init(ptc.Typ.REQ, ptc.Act.MSG, client.id, "client", addr_str, val);

                // send message protocol to server
                msgp.dump(LOG_LEVEL);
                msgp.transmit(msg_stream);
            } else if (mem.startsWith(u8, user_input, ":exit")) {
                const msg_stream = try net.tcpConnectToAddress(addr);
                defer msg_stream.close();
                const endp = ptc.Protocol.init(ptc.Typ.REQ, ptc.Act.COMM_END, client.id, "client", addr_str, "");
                endp.dump(LOG_LEVEL);
                endp.transmit(msg_stream);
                break;
            } else if (mem.startsWith(u8, user_input, ":help")) {
                print_usage();
            } else {
                print("Unknown command: `{s}`\n", .{user_input});
                print_usage();
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
    var client = try request_connection(addr);
    defer print("Client stopped\n", .{});

    {
        const t1 = try std.Thread.spawn(.{}, listen_for_comms, .{&client});
        defer t1.join();
        errdefer t1.join();
        const t2 = try std.Thread.spawn(.{}, read_cmd, .{ addr, &client });
        defer t2.join();
        errdefer t2.join();
    }
}
