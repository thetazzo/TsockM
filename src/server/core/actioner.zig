const std = @import("std");
const SharedData = @import("core.zig").SharedData;
const Protocol = @import("aids").Protocol;

pub const Action = struct {
    collect: ?struct {
        request:  *const fn (std.net.Server.Connection, *SharedData, Protocol) void,
        response: *const fn (*SharedData, Protocol) void,
        err:    *const fn () void,
    },
    transmit: ?struct {
        request:  *const fn (Protocol.TransmitionMode, *SharedData, []const u8) void,
        response: *const fn () void,
        err:      *const fn () void,
    },
    internal: ?*const fn (*SharedData) void,
};

pub const Act = enum {
    COMM,
    COMM_END,
    MSG,
    GET_PEER,
    NTFY_KILL,
    NONE,
    CLEAN_PEER_POOL,
};

pub fn parseAct(act: Protocol.Act) Act {
    return switch (act) {
        .COMM => Act.COMM,
        .COMM_END => Act.COMM_END,
        .MSG => Act.MSG,
        .GET_PEER => Act.GET_PEER,
        .NTFY_KILL => Act.NTFY_KILL,
        .NONE => Act.NONE,
    };
}

pub const Actioner = struct {
    actions: std.AutoHashMap(Act, Action), 
    pub fn init(allocator: std.mem.Allocator) Actioner {
        const actions = std.AutoHashMap(Act, Action).init(allocator);
        return Actioner{
            .actions = actions, 
        };
    }
    pub fn add(self: *@This(), caller: Act, act: Action) void {
        self.actions.put(caller, act) catch |err| {
            std.log.err("`core::Actioner::add`: {any}\n", .{err});
            std.posix.exit(1);
        };
    }
    pub fn get(self: *@This(), caller: Act) ?Action {
        return self.actions.get(caller);
    }
    pub fn deinit(self: *@This()) void {
        self.actions.deinit();
    }
};
