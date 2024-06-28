const std = @import("std");

pub const Typ = enum(u8) {
    REQ,
    RES,
    ERR,
    NONE,
};

pub const Act = enum(u8) {
    COMM,
    COMM_END,
    MSG,
    GET_PEER,
    NTFY_KILL,
    NONE,
};

pub const Status = enum(u16) {
    OK = 200,
    BAD_REQUEST = 400,
    NOT_FOUND = 404,
    METHOD_NOT_ALLOWED = 405,
    BAD_GATEWAY = 502,
};

pub const Protocol = @import("protocol.zig").Protocol;

pub const protocols = struct {
    pub const NOT_FOUND = @import("not-found.zig").NotFound;
};

pub fn typAsStr(typ: Typ) []const u8 {
    switch (typ) {
        .REQ => return "request",
        .RES => return "response",
        .ERR => return "error",
        .NONE => return "none",
    }
}

pub fn statusAsStr(code: Status) []const u8 {
    switch (code) {
        .OK => return "200",
        .BAD_REQUEST => return "400",
        .NOT_FOUND => return "404",
        .METHOD_NOT_ALLOWED => return "405",
        .BAD_GATEWAY => return "502",
    }
}

pub fn statusFromStr(code: []const u8) Status {
    if (std.mem.eql(u8, code, "200")) {
        return .OK;
    } else if (std.mem.eql(u8, code, "400")) {
        return .BAD_REQUEST;
    } else if (std.mem.eql(u8, code, "404")) {
        return .NOT_FOUND;
    } else if (std.mem.eql(u8, code, "405")) {
        return .METHOD_NOT_ALLOWED;
    } else if (std.mem.eql(u8, code, "502")) {
        return .BAD_GATEWAY;
    } else {
        std.log.err("unreachable `{s}`", .{code});
        unreachable;
    }
}

pub fn protocolFromStr(str: []const u8) Protocol {
    var spl = std.mem.split(u8, str, "::");
    var prot_type: Typ = undefined;
    var prot_action: Act = undefined;
    var prot_status: Status = undefined;
    var prot_sender_id: []const u8 = "unknown";
    var prot_src_addr_str: []const u8 = "unknown";
    var prot_dest_addr_str: []const u8 = "unknown";
    var prot_body_str: []const u8 = "unknown";
    if (spl.next()) |typ| {
        if (std.meta.stringToEnum(Typ, typ)) |etyp| {
            prot_type = etyp;
        } else {
            std.log.err("Something went wrong with prot_ol type: `{s}`\n", .{typ});
            prot_type = .ERR;
            prot_action = .NONE;
            prot_status = .BAD_GATEWAY;
            prot_body_str = @tagName(.BAD_GATEWAY);
        }
    }
    if (spl.next()) |act| {
        if (std.meta.stringToEnum(Act, act)) |eact| {
            prot_action = eact;
        } else {
            std.log.err("Something went wrong with prot_ol action: `{s}`\n", .{act});
            prot_type = .ERR;
            prot_action = .NONE;
            prot_status = .BAD_GATEWAY;
            prot_body_str = @tagName(.BAD_GATEWAY);
        }
    }
    if (spl.next()) |rc| {
        prot_status = statusFromStr(rc);
    }
    if (spl.next()) |id| {
        prot_sender_id = id;
    }
    if (spl.next()) |src| {
        prot_src_addr_str = src;
    }
    if (spl.next()) |dst| {
        prot_dest_addr_str = dst;
    }
    if (spl.next()) |bdy| {
        prot_body_str = bdy;
    }
    return Protocol{
        .type = prot_type,
        .action = prot_action,
        .status_code = prot_status,
        .sender_id = prot_sender_id,
        .src_addr = prot_src_addr_str,
        .dest_addr = prot_dest_addr_str,
        .body = prot_body_str,
    };
}

test "communication type" {
    try std.testing.expectEqualStrings("none", typAsStr(.NONE));
    try std.testing.expectEqualStrings("error", typAsStr(.ERR));
    try std.testing.expectEqualStrings("request", typAsStr(.REQ));
    try std.testing.expectEqualStrings("response", typAsStr(.RES));
}

test "status as string" {
    try std.testing.expectEqualStrings("200", statusAsStr(.OK));
    try std.testing.expectEqualStrings("400", statusAsStr(.BAD_REQUEST));
    try std.testing.expectEqualStrings("404", statusAsStr(.NOT_FOUND));
    try std.testing.expectEqualStrings("405", statusAsStr(.METHOD_NOT_ALLOWED));
    try std.testing.expectEqualStrings("502", statusAsStr(.BAD_GATEWAY));
}

test "status from string" {
    try std.testing.expectEqual(Status.OK, statusFromStr("200"));
    try std.testing.expectEqual(Status.BAD_REQUEST, statusFromStr("400"));
    try std.testing.expectEqual(Status.NOT_FOUND, statusFromStr("404"));
    try std.testing.expectEqual(Status.METHOD_NOT_ALLOWED, statusFromStr("405"));
    try std.testing.expectEqual(Status.BAD_GATEWAY, statusFromStr("502"));
}

test "protocol from string" {
    const prot: Protocol = Protocol{
        .type = .REQ,
        .action = .NONE,
        .status_code = .OK,
        .sender_id = "tester",
        .src_addr = "test",
        .dest_addr = "test",
        .body = "",
    };
    const prot_str = "REQ::NONE::200::tester::test::test::";

    try std.testing.expect(prot.eql(protocolFromStr(prot_str)));
}
