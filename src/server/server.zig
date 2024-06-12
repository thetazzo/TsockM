const std = @import("std");
const aids = @import("aids");
const core = @import("core/core.zig");
const ServerAction = @import("actions/actions.zig");
const ServerCommand = @import("commands/commands.zig");
const Server = core.Server;
const Peer = core.Peer;
const SharedData = core.SharedData;
const Protocol = aids.Protocol;
const Logging = aids.Logging;
const mem = std.mem;
const print = std.debug.print;

const str_allocator = std.heap.page_allocator;

/// I am thread
fn listener(
    sd: *SharedData,
) !void {
    while (!sd.should_exit) {
        const conn = try sd.server.net_server.accept();

        const stream = conn.stream;

        var buf: [256]u8 = undefined;
        _ = try stream.read(&buf);
        const recv = mem.sliceTo(&buf, 170);

        // Handle communication request
        var protocol = Protocol.protocolFromStr(recv); // parse protocol from recieved bytes
        protocol.dump(sd.server.log_level);

        const opt_action = sd.server.Actioner.get(core.ParseAct(protocol.action));
        if (opt_action) |act| {
            switch (protocol.type) {
                // TODO: better handling of optional types
                .REQ => act.collect.?.request(conn, sd, protocol),
                .RES => act.collect.?.response(sd, protocol),
                .ERR => act.collect.?.err(),
                else => {
                    std.log.err("`therad::listener`: unknown protocol type!", .{});
                    unreachable;
                }
            }
        }
    }
    print("Ending `listener`\n", .{});
}

/// i am a thread
fn commander(
    sd: *SharedData,
) !void {
    while (!sd.should_exit) {
        // read for command
        var buf: [256]u8 = undefined;
        const stdin = std.io.getStdIn().reader();
        if (try stdin.readUntilDelimiterOrEof(buf[0..], '\n')) |user_input| {
            // Handle different commands
            var splits = mem.splitScalar(u8, user_input, ' ');
            if (splits.next()) |ui| {
                if (sd.server.Commander.get(ui)) |cmd| {
                    cmd.executor(user_input, sd);
                } else {
                    std.log.err("Unknown command: `{s}`\n", .{user_input});
                    ServerCommand.PRINT_PROGRAM_USAGE.executor(null, sd);
                }
            }
        } else {
            std.log.err("something went wrong when reading stdin!", .{});
            std.posix.exit(1);
        }
    }
    print("Thread `run_cmd` finished\n", .{});
}

/// this is a thread
fn polizei(sd: *SharedData) !void {
    var start_t = try std.time.Instant.now();
    var lock = false;
    while (!sd.should_exit) {
        const now_t = try std.time.Instant.now();
        const dt  = now_t.since(start_t) / std.time.ns_per_ms;
        if (dt == 2000 and !lock) {
            ServerAction.COMM_ACTION.transmit.?.request(Protocol.TransmitionMode.BROADCAST, sd, "");
            lock = true;
        }
        if (dt == 3000 and lock) {
            ServerAction.NTFY_KILL_ACTION.transmit.?.request(Protocol.TransmitionMode.BROADCAST, sd, "");
            lock = false;
        }
        if (dt == 4000 and !lock) {
            ServerAction.CLEAN_PEER_POOL_ACTION.internal.?(sd);
            lock = false;
            start_t = try std.time.Instant.now();
        }
    }
}

pub fn start(hostname: []const u8, port: u16, log_level: Logging.Level) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_allocator = gpa.allocator();

    var server = Server.init(gpa_allocator, hostname, port, log_level);
    defer server.deinit();

    server.Actioner.add(core.Act.COMM, ServerAction.COMM_ACTION);
    server.Actioner.add(core.Act.COMM_END, ServerAction.COMM_END_ACTION);
    server.Actioner.add(core.Act.MSG, ServerAction.MSG_ACTION);
    server.Actioner.add(core.Act.GET_PEER, ServerAction.GET_PEER_ACTION);
    server.Actioner.add(core.Act.NTFY_KILL, ServerAction.NTFY_KILL_ACTION);
    server.Actioner.add(core.Act.NONE, ServerAction.BAD_REQUEST_ACTION);
    server.Actioner.add(core.Act.CLEAN_PEER_POOL, ServerAction.CLEAN_PEER_POOL_ACTION);

    server.Commander.add(":exit", ServerCommand.EXIT_SERVER);
    server.Commander.add(":info", ServerCommand.PRINT_SERVER_STATS);
    server.Commander.add(":list", ServerCommand.LIST_ACTIVE_PEERS);
    server.Commander.add(":ls",   ServerCommand.LIST_ACTIVE_PEERS);
    server.Commander.add(":kill", ServerCommand.KILL_PEER);
    server.Commander.add(":ping", ServerCommand.PING);
    server.Commander.add(":c",    ServerCommand.CLEAR_SCREEN);
    server.Commander.add(":clean-pool", ServerCommand.CLEAN_PEER_POOL);
    server.Commander.add(":help", ServerCommand.PRINT_PROGRAM_USAGE);

    var peer_pool = std.ArrayList(Peer).init(gpa_allocator);
    defer peer_pool.deinit();

    server.start();

    var thread_pool: [3]std.Thread = undefined;
    var sd = SharedData{
        .m = std.Thread.Mutex{},
        .should_exit = false,
        .peer_pool = &peer_pool,
        .server = server,
    };
    {
        thread_pool[0] = try std.Thread.spawn(.{}, listener, .{ &sd });
        thread_pool[1] = try std.Thread.spawn(.{}, commander, .{ &sd });
        thread_pool[2] = try std.Thread.spawn(.{}, polizei, .{ &sd });
    }
    defer for(thread_pool) |thr| thr.join();
}
