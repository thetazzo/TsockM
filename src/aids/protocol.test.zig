const std = @import("std");
const print = std.debug.print;
const Protocol = @import("protocol.zig");

const SILENT = true;

fn equalStr(s1: []const u8, s2: []const u8) bool {
    if (!SILENT) {
        print("-----------------------------------------\n", .{});
        print("    expected: `{s}`\n", .{s1});
        print("    got: `{s}`\n", .{s2});
        print("-----------------------------------------\n", .{});
    }
    return std.mem.eql(u8, s1, s2);
}
fn equalEnum(comptime T: type, s1: T, s2: T) bool {
    if (!SILENT) {
        print("-----------------------------------------\n", .{});
        print("    expected: `{s}`\n", .{@tagName(s1)});
        print("    got: `{s}`\n", .{@tagName(s2)});
        print("-----------------------------------------\n", .{});
    }
    return s1 == s2;
}

test "Protocol.protTypeAsStr" {
    std.debug.print("====================================================\n", .{});
    std.debug.print("Protocol.protTypeAsStr\n", .{});
    std.debug.print("====================================================\n", .{});
    try std.testing.expect(equalStr("none", Protocol.prot_type_as_str(Protocol.Typ.NONE)));
    try std.testing.expect(equalStr("request", Protocol.prot_type_as_str(Protocol.Typ.REQ)));
    try std.testing.expect(equalStr("response", Protocol.prot_type_as_str(Protocol.Typ.RES)));
    try std.testing.expect(equalStr("error", Protocol.prot_type_as_str(Protocol.Typ.ERR)));
}

test "Protocol.statusCodeAsStr" {
    std.debug.print("====================================================\n", .{});
    std.debug.print("Protocol.statusCodeAsStr\n", .{});
    std.debug.print("====================================================\n", .{});
    try std.testing.expect(
        equalStr("200", Protocol.statuscode_as_str(Protocol.StatusCode.OK)),
    );
    try std.testing.expect(
        equalStr("404", Protocol.statuscode_as_str(Protocol.StatusCode.NOT_FOUND)),
    );
    try std.testing.expect(
        equalStr("400", Protocol.statuscode_as_str(Protocol.StatusCode.BAD_REQUEST)),
    );
    try std.testing.expect(
        equalStr("405", Protocol.statuscode_as_str(Protocol.StatusCode.METHOD_NOT_ALLOWED)),
    );
    try std.testing.expect(
        equalStr("502", Protocol.statuscode_as_str(Protocol.StatusCode.BAD_GATEWAY)),
    );
}

test "Protocol.strAsRetCode" {
    std.debug.print("====================================================\n", .{});
    std.debug.print("Protocol.stringAsRetCode\n", .{});
    std.debug.print("====================================================\n", .{});
    try std.testing.expect(
        equalEnum(
            Protocol.StatusCode,
            Protocol.StatusCode.OK,
            Protocol.str_as_retcode("200"),
        ),
    );
    try std.testing.expect(
        equalEnum(
            Protocol.StatusCode,
            Protocol.StatusCode.NOT_FOUND,
            Protocol.str_as_retcode("404"),
        ),
    );
    try std.testing.expect(
        equalEnum(
            Protocol.StatusCode,
            Protocol.StatusCode.BAD_REQUEST,
            Protocol.str_as_retcode("400"),
        ),
    );
    try std.testing.expect(
        equalEnum(
            Protocol.StatusCode,
            Protocol.StatusCode.METHOD_NOT_ALLOWED,
            Protocol.str_as_retcode("405"),
        ),
    );
    try std.testing.expect(
        equalEnum(
            Protocol.StatusCode,
            Protocol.StatusCode.BAD_GATEWAY,
            Protocol.str_as_retcode("502"),
        ),
    );
}

var p: Protocol = Protocol.init(
    Protocol.Typ.REQ,
    Protocol.Act.NONE,
    Protocol.StatusCode.OK,
    "fu",
    "test",
    "test",
    "",
);

test "Protocol.asStr" {
    std.debug.print("====================================================\n", .{});
    std.debug.print("Protocol.asStr\n", .{});
    std.debug.print("====================================================\n", .{});
    try std.testing.expect(equalStr("REQ::NONE::200::fu::test::test::", p.as_str()));
}
