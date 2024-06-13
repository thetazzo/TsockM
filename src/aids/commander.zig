const std = @import("std");

const CMD = []const u8;

pub fn Command(comptime T: type) type {
    return struct {
        executor: *const fn (?[]const u8, ?*T) void,
    };
}

pub fn Commander(comptime T: type) type {
    return struct{
        commands: std.StringHashMap(T), 
        pub fn init(allocator: std.mem.Allocator) Commander(T) {
            const commands = std.StringHashMap(T).init(allocator);
            return Commander(T){
                .commands = commands, 
            };
        }
        pub fn add(self: *@This(), caller: CMD, cmd: T) void {
            self.commands.put(caller, cmd) catch |err| {
                std.log.err("`core::Commander::add`: {any}\n", .{err});
                std.posix.exit(1);
            };
        }
        pub fn get(self: *@This(), caller: CMD) ?T {
            return self.commands.get(caller);
        }
        pub fn deinit(self: *@This()) void {
            self.commands.deinit();
        }
    };
}
