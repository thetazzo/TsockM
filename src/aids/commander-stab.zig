const std = @import("std");

const CMD = []const u8;

pub fn Command(comptime data: type) type {
    return struct {
        executor: *const fn (?[]const u8, ?*data) void,
    };
}

pub fn Commander(comptime data: type) type {
    return struct{
        commands: std.StringHashMap(data), 
        pub fn init(allocator: std.mem.Allocator) Commander(data) {
            const commands = std.StringHashMap(data).init(allocator);
            return Commander(data){
                .commands = commands, 
            };
        }
        pub fn add(self: *@This(), caller: CMD, cmd: data) void {
            self.commands.put(caller, cmd) catch |err| {
                std.log.err("`core::Commander::add`: {any}\n", .{err});
                std.posix.exit(1);
            };
        }
        pub fn get(self: *@This(), caller: CMD) ?data {
            return self.commands.get(caller);
        }
        pub fn deinit(self: *@This()) void {
            self.commands.deinit();
        }
    };
}
