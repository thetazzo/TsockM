const std = @import("std");
const print = std.debug.print;
const proto = @import("protocol.zig");

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
    try std.testing.expect(equalStr("none", proto.prot_type_as_str(proto.Typ.NONE)));
    try std.testing.expect(equalStr("request", proto.prot_type_as_str(proto.Typ.REQ)));
    try std.testing.expect(equalStr("response", proto.prot_type_as_str(proto.Typ.RES)));
    try std.testing.expect(equalStr("error", proto.prot_type_as_str(proto.Typ.ERR)));
}

test "Protocol.statusCodeAsStr" {
    std.debug.print("====================================================\n", .{});
    std.debug.print("Protocol.statusCodeAsStr\n", .{});
    std.debug.print("====================================================\n", .{});
    try std.testing.expect(
        equalStr("200", proto.statuscode_as_str(proto.StatusCode.OK)),
    );
    try std.testing.expect(
        equalStr("404", proto.statuscode_as_str(proto.StatusCode.NOT_FOUND)),
    );
    try std.testing.expect(
        equalStr("400", proto.statuscode_as_str(proto.StatusCode.BAD_REQUEST)),
    );
    try std.testing.expect(
        equalStr("405", proto.statuscode_as_str(proto.StatusCode.METHOD_NOT_ALLOWED)),
    );
    try std.testing.expect(
        equalStr("502", proto.statuscode_as_str(proto.StatusCode.BAD_GATEWAY)),
    );
}

test "Protocol.strAsRetCode" {
    std.debug.print("====================================================\n", .{});
    std.debug.print("Protocol.stringAsRetCode\n", .{});
    std.debug.print("====================================================\n", .{});
    try std.testing.expect(
        equalEnum(
            proto.StatusCode,
            proto.StatusCode.OK,
            proto.str_as_retcode("200"),
        ),
    );
    try std.testing.expect(
        equalEnum(
            proto.StatusCode,
            proto.StatusCode.NOT_FOUND,
            proto.str_as_retcode("404"),
        ),
    );
    try std.testing.expect(
        equalEnum(
            proto.StatusCode,
            proto.StatusCode.BAD_REQUEST,
            proto.str_as_retcode("400"),
        ),
    );
    try std.testing.expect(
        equalEnum(
            proto.StatusCode,
            proto.StatusCode.METHOD_NOT_ALLOWED,
            proto.str_as_retcode("405"),
        ),
    );
    try std.testing.expect(
        equalEnum(
            proto.StatusCode,
            proto.StatusCode.BAD_GATEWAY,
            proto.str_as_retcode("502"),
        ),
    );
}

var p: proto.Protocol = proto.Protocol.init(
    proto.Typ.REQ,
    proto.Act.NONE,
    proto.StatusCode.OK,
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
