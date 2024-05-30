const std = @import("std");
const ptc = @import("ptc");
const cmn = @import("cmn");
const mem = std.mem;
const net = std.net;
const print = std.debug.print;

const str_allocator = std.heap.page_allocator;

const LOG_LEVEL = ptc.LogLevel.SILENT;

const Client = struct {
    id: []const u8,
    username: []const u8,
    stream: net.Stream,
    comm_addr: ptc.Addr,

    pub fn dump(self: @This()) void {
        print("------------------------------------\n", .{});
        print("Client {{\n", .{});
        print("    id: `{s}`\n", .{self.id});
        print("    username: `{s}`\n", .{self.username});
        print("    comm_addr: `{s}`\n", .{self.comm_addr});
        print("}}\n", .{});
        print("------------------------------------\n", .{});
    }
};

fn print_usage() void {
    print("COMMANDS:\n", .{});
    print("    * :msg <message> .... boradcast the message to all users\n", .{});
    print("    * :gp <peer_id> ..... request peer data from server\n", .{});
    print("    * :exit ............. terminate the program\n", .{});
}

fn request_connection(addr: net.Address, username: []const u8) !Client {
    const stream = try net.tcpConnectToAddress(addr);
    const dst_addr = cmn.address_as_str(addr);
    // request connection
    const reqp = ptc.Protocol.init(
        ptc.Typ.REQ,
        ptc.Act.COMM,
        ptc.StatusCode.OK,
        "client",
        "client",
        dst_addr,
        username,
    );
    reqp.dump(LOG_LEVEL);
    _ = ptc.prot_transmit(stream, reqp);

    const resp = try ptc.prot_collect(str_allocator, stream);
    resp.dump(LOG_LEVEL);

    // construct the clint
    var c = Client{
        .id = resp.body,
        .username = username,
        .stream = stream,
        .comm_addr = resp.dst,
    };
    c.dump(); // print the client

    return c;
}

fn send_request(addr: net.Address, req: ptc.Protocol) !void {
    // Open a sterm to the server
    const req_stream = try net.tcpConnectToAddress(addr);
    defer req_stream.close();

    // send protocol to server
    req.dump(LOG_LEVEL);
    _ = ptc.prot_transmit(req_stream, req);
}

// Data to share between threads
const SharedData = struct {
    m: std.Thread.Mutex,
    should_exit: bool,

    pub fn update_value(self: *@This(), should: bool) void {
        self.m.lock();
        defer self.m.unlock();

        self.should_exit = should;
    }
};

fn listen_for_comms(sd: *SharedData, addr: net.Address, client: *Client) !void {
    const addr_str = cmn.address_as_str(addr);
    while (true) {
        const resp = try ptc.prot_collect(str_allocator, client.stream);
        resp.dump(LOG_LEVEL);
        if (resp.is_response()) {
            if (resp.is_action(ptc.Act.COMM_END)) {
                if (resp.status_code == ptc.StatusCode.OK) {
                    client.stream.close();
                    break;
                }
            } else if (resp.is_action(ptc.Act.GET_PEER)) {
                if (resp.status_code == ptc.StatusCode.OK) {
                    const peer_name = resp.body;
                    print("Peer name is: {s}\n", .{peer_name});
                }
            } else if (resp.is_action(ptc.Act.MSG)) {
                if (resp.status_code == ptc.StatusCode.OK) {
                    // construct protocol to get peer data
                    const reqp = ptc.Protocol.init(
                        ptc.Typ.REQ, // type
                        ptc.Act.GET_PEER, // action
                        ptc.StatusCode.OK, // status code
                        client.id, // sender id
                        "client", // src address
                        addr_str, // destination address
                        resp.sender_id, //body
                    );
                    try send_request(addr, reqp);

                    // collect GET_PEER response
                    const np = try ptc.prot_collect(str_allocator, client.stream);
                    np.dump(LOG_LEVEL);

                    print("{s}: {s}\n", .{ np.body, resp.body });
                } else {
                    resp.dump(LOG_LEVEL);
                }
            }
        } else if (resp.type == ptc.Typ.REQ) {
            if (resp.status_code == ptc.StatusCode.OK) {
                if (resp.is_action(ptc.Act.COMM)) {
                    // protocol to say communication is OK
                    const msgp = ptc.Protocol.init(
                        ptc.Typ.RES,
                        ptc.Act.COMM,
                        ptc.StatusCode.OK,
                        client.id,
                        "client",
                        addr_str,
                        "OK",
                    );
                    // send message protocol to server
                    try send_request(addr, msgp);
                }
            }
        } else if (resp.type == ptc.Typ.ERR) {
            //client.stream.close();
            resp.dump(LOG_LEVEL);
            break;
        }
    }
    print("exiting listen_for_comms\n", .{});
    sd.update_value(true);
}

fn extract_command_val(cs: []const u8, cmd: []const u8) []const u8 {
    var splits = mem.split(u8, cs, cmd);
    _ = splits.next().?; // the `:msg` part
    const val = mem.trimLeft(u8, splits.next().?, " \n");
    if (val.len <= 0) {
        std.log.err("missing action value", .{});
        print_usage();
    }
    return val;
}

fn read_cmd(sd: *SharedData, addr: net.Address, client: *Client) !void {
    const addr_str = cmn.address_as_str(addr);
    while (!sd.should_exit) {
        // read for command
        var buf: [256]u8 = undefined;
        const stdin = std.io.getStdIn().reader();
        if (try stdin.readUntilDelimiterOrEof(buf[0..], '\n')) |user_input| {
            // Handle different commands
            if (mem.startsWith(u8, user_input, ":msg")) {
                const msg = extract_command_val(user_input, ":msg");

                // construct message protocol
                const reqp = ptc.Protocol.init(
                    ptc.Typ.REQ,
                    ptc.Act.MSG,
                    ptc.StatusCode.OK,
                    client.id,
                    "client",
                    addr_str,
                    msg,
                );

                try send_request(addr, reqp);
            } else if (mem.startsWith(u8, user_input, ":gp")) {
                const pid = extract_command_val(user_input, ":gp");

                // construct message protocol
                const reqp = ptc.Protocol.init(
                    ptc.Typ.REQ,
                    ptc.Act.GET_PEER,
                    ptc.StatusCode.OK,
                    client.id,
                    "client",
                    addr_str,
                    pid,
                );

                try send_request(addr, reqp);
            } else if (mem.eql(u8, user_input, ":exit")) {
                const reqp = ptc.Protocol.init(
                    ptc.Typ.REQ,
                    ptc.Act.COMM_END,
                    ptc.StatusCode.OK,
                    client.id,
                    "client",
                    addr_str,
                    "",
                );
                sd.update_value(true);
                try send_request(addr, reqp);
            } else if (mem.eql(u8, user_input, ":cc")) {
                try cmn.screen_clear();
                client.dump();
            } else if (mem.eql(u8, user_input, ":help")) {
                print_usage();
            } else {
                print("Unknown command: `{s}`\n", .{user_input});
                print_usage();
            }
        } else {
            print("Unreachable, maybe?\n", .{});
        }
    }
    print("exiting read_cmd\n", .{});
}

pub fn start() !void {
    try cmn.screen_clear();
    print("Client starated\n", .{});
    print("Enter your username: ", .{});
    const addr = try net.Address.resolveIp("127.0.0.1", 6969);
    var buf: [256]u8 = undefined;
    const stdin = std.io.getStdIn().reader();
    if (try stdin.readUntilDelimiterOrEof(buf[0..], '\n')) |user_input| {
        // communication request
        var client = try request_connection(addr, user_input);
        defer print("Client stopped\n", .{});
        var sd = SharedData{
            .m = std.Thread.Mutex{},
            .should_exit = false,
        };
        {
            const t1 = try std.Thread.spawn(.{}, listen_for_comms, .{ &sd, addr, &client });
            defer t1.join();
            errdefer t1.join();
            const t2 = try std.Thread.spawn(.{}, read_cmd, .{ &sd, addr, &client });
            defer t2.join();
            errdefer t2.join();
        }
    }
}
