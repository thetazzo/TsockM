const std = @import("std");
const Action = @import("../core/core.zig").Action;

fn onRequest() void {
    std.log.err("not implemented", .{});
}

fn onResponse() void {
    std.log.err("not implemented", .{});
}

fn onError() void {
    std.log.err("not implemented", .{});
}

pub const COMM_ACTION = Action{
    .onRequest = onRequest,
    .onResponse = onResponse,
    .onError = onError,
};
