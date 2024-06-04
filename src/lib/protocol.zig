const std = @import("std");
const mem = std.mem;
const print = std.debug.print;

pub const Typ = enum {
    REQ,
    RES,
    ERR,
    NONE,
};

fn prot_type_as_str(typ: Typ) []const u8 {
    switch (typ) {
        Typ.REQ => return "request",
        Typ.RES => return "response",
        Typ.ERR => return "error",
        Typ.NONE => return "none",
    }
}

pub const Act = enum {
    COMM,
    COMM_END,
    MSG,
    GET_PEER,
    NONE,
};

pub const StatusCode = enum(u16) {
    OK = 200,
    BAD_REQUEST = 400,
    NOT_FOUND = 404,
    METHOD_NOT_ALLOWED = 405,
    BAD_GATEWAY = 502,
};

pub fn statuscode_as_str(code: StatusCode) []const u8 {
    switch (code) {
        StatusCode.OK => return "200",
        StatusCode.BAD_REQUEST => return "400",
        StatusCode.NOT_FOUND => return "404",
        StatusCode.METHOD_NOT_ALLOWED => return "405",
        StatusCode.BAD_GATEWAY => return "502",
    }
}

pub fn str_as_retcode(code: []const u8) StatusCode {
    if (mem.eql(u8, code, "200")) {
        return StatusCode.OK;
    } else if (mem.eql(u8, code, "400")) {
        return StatusCode.BAD_REQUEST;
    } else if (mem.eql(u8, code, "404")) {
        return StatusCode.NOT_FOUND;
    } else if (mem.eql(u8, code, "405")) {
        return StatusCode.METHOD_NOT_ALLOWED;
    } else if (mem.eql(u8, code, "502")) {
        return StatusCode.BAD_GATEWAY;
    } else {
        std.log.err("unreachable", .{});
        unreachable;
    }
}

pub const LogLevel = enum {
    SILENT,
    DEV,
    TINY,
    REQ,
};

pub const Id = []const u8;
pub const Body = []const u8;
pub const Addr = []const u8;

// [type]::[action]::[status_code]::[id]::[src]::[dst]::[body]
pub const Protocol = struct {
    type: Typ = Typ.NONE,
    action: Act = Act.NONE,
    status_code: StatusCode = StatusCode.NOT_FOUND,
    sender_id: Id = "",
    body: Body = "",
    src: Addr = "",
    dst: Addr = "",
    pub fn init(
        typ: Typ,
        action: Act,
        status_code: StatusCode,
        sender_id: Id,
        src: Addr,
        dst: Addr,
        bdy: Body,
    ) Protocol {
        return Protocol{
            .type = typ, // type
            .action = action, // action
            .status_code = status_code, // status_code
            .sender_id = sender_id, // sender_id
            .src = src, // src_address
            .dst = dst, // dst_addres
            .body = bdy, // body
        };
    }
    pub fn dump(self: @This(), log_level: LogLevel) void {
        if (log_level == LogLevel.SILENT) return;

        if (log_level == LogLevel.REQ and self.type != Typ.REQ) return;

        print("====================================\n", .{});
        print(" {s}: `{s}` {{{s}}}                 \n", .{
            prot_type_as_str(self.type),
            @tagName(self.action),
            self.sender_id,
        });
        if (log_level == LogLevel.DEV) {
            print("------------------------------------\n", .{});
            print(" Protocol \n", .{});
            print("     type:      `{s}`\n", .{@tagName(self.type)});
            print("     action:    `{s}`\n", .{@tagName(self.action)});
            print("     status_code:  `{s}`\n", .{statuscode_as_str(self.status_code)});
            print("     sender_id: `{s}`\n", .{self.sender_id});
            print("     src_addr:  `{s}`\n", .{self.src});
            print("     dst_addr:  `{s}`\n", .{self.dst});
            print("     body:      `{s}`\n", .{self.body});
        }
        print("====================================\n", .{});
    }
    pub fn as_str(self: @This()) []const u8 {
        var buf: [512]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        var string = std.ArrayList(u8).init(fba.allocator());
        _ = string.appendSlice(@tagName(self.type)) catch "OutOfMemory";
        _ = string.appendSlice("::") catch "OutOfMemory";
        _ = string.appendSlice(@tagName(self.action)) catch "OutOfMemory";
        _ = string.appendSlice("::") catch "OutOfMemory";
        _ = string.appendSlice(statuscode_as_str(self.status_code)) catch "OutOfMemory";
        _ = string.appendSlice("::") catch "OutOfMemory";
        _ = string.appendSlice(self.sender_id) catch "OutOfMemory";
        _ = string.appendSlice("::") catch "OutOfMemory";
        _ = string.appendSlice(self.src) catch "OutOfMemory";
        _ = string.appendSlice("::") catch "OutOfMemory";
        _ = string.appendSlice(self.dst) catch "OutOfMemory";
        _ = string.appendSlice("::") catch "OutOfMemory";
        _ = string.appendSlice(self.body) catch "OutOfMemory";
        return string.items;
    }
    pub fn is_request(self: @This()) bool {
        return self.type == Typ.REQ;
    }
    pub fn is_response(self: @This()) bool {
        return self.type == Typ.RES;
    }
    pub fn is_action(self: @This(), act: Act) bool {
        return self.action == act;
    }
};

// returns 1 when stream is closed
pub fn prot_transmit(stream: std.net.Stream, prot: Protocol) u8 {
    const werr = stream.write(prot.as_str()) catch 1;
    if (werr == 1) {
        return 1;
    }
    return 0;
}

pub fn prot_collect(allocator: mem.Allocator, stream: std.net.Stream) !Protocol {
    var buf: [1024]u8 = undefined;
    _ = try stream.read(&buf);
    const resps = mem.sliceTo(&buf, 170);
    const respss = try std.fmt.allocPrint(allocator, "{s}", .{resps});
    const resp = protocol_from_str(respss);
    return resp;
}

pub fn protocol_from_str(str: []const u8) Protocol {
    var spl = mem.split(u8, str, "::");
    // [type]::[action]::[status_code]::[id]::[src]::[dst]::[body]

    // Empty protocol
    var proto = Protocol{};

    if (spl.next()) |typ| {
        if (std.meta.stringToEnum(Typ, typ)) |etyp| {
            proto.type = etyp;
        } else {
            std.log.err("Something went wrong with protocol type: `{s}`\n", .{typ});
            proto.type = Typ.ERR;
            proto.action = Act.NONE;
            proto.status_code = StatusCode.BAD_GATEWAY;
            proto.body = @tagName(StatusCode.BAD_GATEWAY);
            return proto;
        }
    }
    if (spl.next()) |act| {
        if (std.meta.stringToEnum(Act, act)) |eact| {
            proto.action = eact;
        } else {
            std.log.err("Something went wrong with protocol action: `{s}`\n", .{act});
        }
    }
    if (spl.next()) |rc| {
        proto.status_code = str_as_retcode(rc);
    }
    if (spl.next()) |id| {
        proto.sender_id = id;
    }
    if (spl.next()) |src| {
        proto.src = src;
    }
    if (spl.next()) |dst| {
        proto.dst = dst;
    }
    if (spl.next()) |bdy| {
        proto.body = bdy;
    }
    return proto;
}
