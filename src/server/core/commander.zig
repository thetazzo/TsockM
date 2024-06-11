const std = @import("std");
const SharedData = @import("core.zig").SharedData;

const CMD = []const u8;

pub const Command = struct {
    executor: *const fn ([]const u8, *SharedData) void,
};

pub const Commander = struct {
    commands: std.StringHashMap(Command), 
    pub fn init(allocator: std.mem.Allocator) Commander {
        const commands = std.StringHashMap(Command).init(allocator);
        return Commander{
            .commands = commands, 
        };
    }
    pub fn add(self: *@This(), caller: CMD, cmd: Command) void {
        self.commands.put(caller, cmd) catch |err| {
            std.log.err("`core::Commander::add`: {any}\n", .{err});
            std.posix.exit(1);
        };
    }
    pub fn get(self: *@This(), caller: CMD) ?Command {
        return self.commands.get(caller);
    }
    pub fn deinit(self: *@This()) void {
        self.commands.deinit();
    }
};
