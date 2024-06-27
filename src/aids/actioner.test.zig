const std = @import("std");
const print = std.debug.print;
const actioner = @import("actioner.zig");
const protocol = @import("protocol.zig");

const SILENT = true;

fn equalEnum(comptime T: type, s1: T, s2: T) bool {
    if (!SILENT) {
        print("-----------------------------------------\n", .{});
        print("    expected: `{s}`\n", .{@tagName(s1)});
        print("    got: `{s}`\n", .{@tagName(s2)});
        print("-----------------------------------------\n", .{});
    }
    return s1 == s2;
}
fn equalNum(comptime T: type, s1: T, s2: T) bool {
    if (!SILENT) {
        print("-----------------------------------------\n", .{});
        print("    expected: `{d}`\n", .{s1});
        print("    got: `{d}`\n", .{s2});
        print("-----------------------------------------\n", .{});
    }
    return s1 == s2;
}
test "Actioner.Act" {
    print("====================================================\n", .{});
    print("Actioner.Act\n", .{});
    print("====================================================\n", .{});
    try std.testing.expect(
        equalNum(usize, 7, std.meta.fields(actioner.Act).len),
    );
}

test "Actioner.parseAct" {
    std.debug.print("====================================================\n", .{});
    std.debug.print("Actioner.parseAct\n", .{});
    std.debug.print("====================================================\n", .{});
    try std.testing.expect(std.meta.fields(actioner.Act).len == 7);
    try std.testing.expect(
        equalEnum(actioner.Act, actioner.Act.NONE, actioner.parseAct(protocol.Act.NONE)),
    );
    try std.testing.expect(
        equalEnum(actioner.Act, actioner.Act.MSG, actioner.parseAct(protocol.Act.MSG)),
    );
    try std.testing.expect(
        equalEnum(actioner.Act, actioner.Act.COMM, actioner.parseAct(protocol.Act.COMM)),
    );
    try std.testing.expect(
        equalEnum(actioner.Act, actioner.Act.COMM_END, actioner.parseAct(protocol.Act.COMM_END)),
    );
    try std.testing.expect(
        equalEnum(actioner.Act, actioner.Act.GET_PEER, actioner.parseAct(protocol.Act.GET_PEER)),
    );
    try std.testing.expect(
        equalEnum(actioner.Act, actioner.Act.NTFY_KILL, actioner.parseAct(protocol.Act.NTFY_KILL)),
    );
}
