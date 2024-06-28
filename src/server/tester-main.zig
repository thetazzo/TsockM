const std = @import("std");
const aids = @import("aids");
const core = @import("core/core.zig");
const ServerActions = @import("actions/actions.zig");

/// I am thread
fn listener(sd: *core.SharedData) !void {
    while (!sd.should_exit) {
        const conn = try sd.server.net_server.accept();

        const stream = conn.stream;

        var buf: [256]u8 = undefined;
        _ = try stream.read(&buf);
        const recv = std.mem.sliceTo(&buf, 170);

        // Handle communication request
        var protocol = aids.proto.fromStr(recv);
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
    }
    std.debug.print("Ending `listener`\n", .{});
}

pub fn main() !void {
    var tmp = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa_allocator = tmp.allocator();
    const str_allocator = std.heap.page_allocator;
    const hostname = "127.0.0.1";
    const port = 8888;
    var t_server = core.sc.Server.init(gpa_allocator, str_allocator, hostname, port, .DEV, "");

    t_server.Actioner.add(.COMM, ServerActions.COMM_ACTION);
    t_server.Actioner.add(.MSG, ServerActions.MSG_ACTION);

    var peer_pool = std.ArrayList(core.pc.Peer).init(gpa_allocator);
    defer peer_pool.deinit();

    t_server.start();

    var thread_pool: [1]std.Thread = undefined;
    var sd = core.SharedData{
        .m = std.Thread.Mutex{},
        .should_exit = false,
        .peer_pool = &peer_pool,
        .server = t_server,
    };
    {
        thread_pool[0] = try std.Thread.spawn(.{}, listener, .{&sd});
        defer for (thread_pool) |thr| thr.join();
    }
}
