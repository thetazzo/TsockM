const std = @import("std");
const aids = @import("aids");
const core = @import("core/core.zig");
const ServerAction = @import("actions/actions.zig");
const ServerCommand = @import("commands/commands.zig");
const comm = aids.v2.comm;
const mem = std.mem;
const print = std.debug.print;

const str_allocator = std.heap.page_allocator;

/// I am thread
fn listener(sd: *core.SharedData) !void {
    while (!sd.should_exit) {
        const conn = try sd.server.net_server.accept();

        const stream = conn.stream;

        var buf: [256]u8 = undefined;
        _ = try stream.read(&buf);
        const recv = mem.sliceTo(&buf, 170);

        // Handle communication request
        var protocol = comm.protocolFromStr(recv);
        protocol.dump(sd.server.log_level);

        const opt_action = sd.server.Actioner.get(aids.Stab.parseAct(protocol.action));
        if (opt_action) |act| {
            switch (protocol.type) {
                // TODO: better handling of optional types
                .REQ => act.collect.?.request(conn, sd, protocol),
                .RES => act.collect.?.response(sd, protocol),
                .ERR => act.collect.?.err(sd),
                else => {
                    std.log.err("`therad::listener`: unknown protocol type!", .{});
                    unreachable;
                },
            }
        }
        if (opt_action == null) {
            std.log.err("Action not found `{s}`", .{@tagName(protocol.action)});
            const resp = comm.protocols.NOT_FOUND(
                protocol.action,
                .SERVER,
                "",
                sd.server.address_str,
                protocol.src_addr,
            );
            const opt_peer_ref = sd.peerPoolFindId(protocol.sender_id);
            if (opt_peer_ref) |peer_ref| {
                _ = resp.transmit(peer_ref.peer.stream()) catch 1;
                resp.dump(sd.server.log_level);
            }
        }
    }
    print("Ending `listener`\n", .{});
}

/// i am a thread
fn commander(sd: *core.SharedData) !void {
    while (!sd.should_exit) {
        // read for command
        var buf: [256]u8 = undefined;
        const stdin = std.io.getStdIn().reader();
        if (try stdin.readUntilDelimiterOrEof(buf[0..], '\n')) |user_input| {
            // Handle different commands
            var splits = mem.splitScalar(u8, user_input, ' ');
            if (splits.next()) |ui| {
                if (sd.server.Commander.get(ui)) |cmd| {
                    cmd.executor(user_input, core.sc.CommandData{ .sd = sd });
                } else {
                    std.log.err("Unknown command: `{s}`\n", .{user_input});
                    ServerCommand.PRINT_PROGRAM_USAGE.executor(null, core.sc.CommandData{ .sd = sd });
                }
            }
        } else {
            std.log.err("something went wrong when reading stdin!", .{});
            std.posix.exit(1);
        }
    }
    print("Thread `run_cmd` finished\n", .{});
}

/// ping peers to determine their life status
/// this is a thread
fn polizei(sd: *core.SharedData) !void {
    var start_t = try std.time.Instant.now();
    var lock = false;
    const CHECK_INTERVAL = 2000; // ms
    while (!sd.should_exit) {
        const now_t = try std.time.Instant.now();
        const dt = now_t.since(start_t) / std.time.ns_per_ms;
        if (dt == CHECK_INTERVAL and !lock) {
            ServerAction.COMM_ACTION.transmit.?.request(comm.TransmitionMode.BROADCAST, sd, "");
            lock = true;
        }
        if (dt == CHECK_INTERVAL + 500 and lock) {
            ServerAction.NTFY_KILL_ACTION.transmit.?.request(comm.TransmitionMode.BROADCAST, sd, "");
            lock = false;
        }
        if (dt == CHECK_INTERVAL + 1001 and !lock) {
            ServerCommand.CLEAN_PEER_POOL.executor("", core.sc.CommandData{ .sd = sd });
            lock = false;
            start_t = try std.time.Instant.now();
        }
    }
}

pub fn start(hostname: []const u8, port: u16, log_level: aids.Logging.Level) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_allocator = gpa.allocator();

    var server = core.sc.Server.init(gpa_allocator, str_allocator, hostname, port, log_level, "0.3.0");
    defer server.deinit();
    defer str_allocator.free(server.address_str);

    // Bind server actions to the server
    server.Actioner.add(aids.Stab.Act.COMM, ServerAction.COMM_ACTION);
    server.Actioner.add(aids.Stab.Act.COMM_END, ServerAction.COMM_END_ACTION);
    server.Actioner.add(aids.Stab.Act.MSG, ServerAction.MSG_ACTION);
    server.Actioner.add(aids.Stab.Act.GET_PEER, ServerAction.GET_PEER_ACTION);
    server.Actioner.add(aids.Stab.Act.NTFY_KILL, ServerAction.NTFY_KILL_ACTION);
    server.Actioner.add(aids.Stab.Act.NONE, ServerAction.BAD_REQUEST_ACTION);

    // Bind server commands to the server
    server.Commander.add(":exit", ServerCommand.EXIT_SERVER);
    server.Commander.add(":info", ServerCommand.PRINT_SERVER_STATS);
    server.Commander.add(":list", ServerCommand.LIST_ACTIVE_PEERS);
    server.Commander.add(":ls", ServerCommand.LIST_ACTIVE_PEERS);
    server.Commander.add(":kill", ServerCommand.KILL_PEER);
    server.Commander.add(":ping", ServerCommand.PING);
    server.Commander.add(":c", ServerCommand.CLEAR_SCREEN);
    server.Commander.add(":clean-pool", ServerCommand.CLEAN_PEER_POOL);
    server.Commander.add(":mute", ServerCommand.MUTE);
    server.Commander.add(":unmute", ServerCommand.UNMUTE);
    server.Commander.add(":help", ServerCommand.PRINT_PROGRAM_USAGE);

    var peer_pool = std.ArrayList(core.Peer).init(gpa_allocator);
    defer peer_pool.deinit();

    server.start();

    var thread_pool: [2]std.Thread = undefined;
    var sd = core.SharedData{
        .m = std.Thread.Mutex{},
        .should_exit = false,
        .peer_pool = &peer_pool,
        .server = server,
    };
    {
        //thread_pool[0] = try std.Thread.spawn(.{}, commander, .{&sd});
        thread_pool[0] = try std.Thread.spawn(.{}, listener, .{&sd});
        thread_pool[1] = try std.Thread.spawn(.{}, polizei, .{&sd});
        defer for (thread_pool) |thr| thr.join();
    }
}
