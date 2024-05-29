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
    std.log.err("unreachable");
    std.os.exit(1);
}

pub const Act = enum {
    COMM,
    COMM_END,
    MSG,
    NONE,
};

pub const LogLevel = enum {
    SILENT,
    DEV,
    TINY,
};

pub const Id = []const u8;
pub const Body = []const u8;
pub const Addr = []const u8;

pub const Protocol = struct {
    type: Typ = Typ.NONE,
    action: Act = Act.NONE,
    id: Id = "",
    body: Body = "",
    src: Addr = "",
    dst: Addr = "",
    pub fn init(typ: Typ, action: Act, id: Id, src: Addr, dst: Addr, bdy: Body) Protocol {
        return Protocol{
            .type = typ,
            .action = action,
            .id = id,
            .src = src,
            .dst = dst,
            .body = bdy,
        };
    }
    pub fn dump(self: @This(), log_level: LogLevel) void {
        if (log_level == LogLevel.SILENT) return;

        print("====================================\n", .{});
        print(" {s}: `{s}`                          \n", .{
            prot_type_as_str(self.type),
            @tagName(self.action),
        });
        if (log_level == LogLevel.DEV) {
            print("------------------------------------\n", .{});
            print(" Protocol \n", .{});
            print("     type: `{s}`\n", .{@tagName(self.type)});
            print("     action: `{s}`\n", .{@tagName(self.action)});
            print("     id: `{s}`\n", .{self.id});
            print("     src_addr: `{s}`\n", .{self.src});
            print("     dst_addr: `{s}`\n", .{self.dst});
            print("     body: `{s}`\n", .{self.body});
        }
        print("====================================\n", .{});
    }
    pub fn as_str(self: @This()) []const u8 {
        var buf: [512]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        var string = std.ArrayList(u8).init(fba.allocator());
        // Consider using the json fomrat instead
        // try std.json.stringify(x, .{}, string.writer());
        _ = string.appendSlice(@tagName(self.type)) catch "OutOfMemory";
        _ = string.appendSlice("::") catch "OutOfMemory";
        _ = string.appendSlice(@tagName(self.action)) catch "OutOfMemory";
        _ = string.appendSlice("::") catch "OutOfMemory";
        _ = string.appendSlice(self.id) catch "OutOfMemory";
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
    pub fn transmit(self: @This(), stream: std.net.Stream) void {
        const werr = stream.write(self.as_str()) catch 1;
        if (werr == 1) {
            std.log.warn("stream is closed\n", .{});
        }
    }
};

pub fn protocol_from_str(str: []const u8) Protocol {
    var spl = mem.split(u8, str, "::");
    // [type]::[action]::[id]::[src]::[dst]::[body]

    // Empty protocol
    var proto = Protocol{};

    if (spl.next()) |typ| {
        if (std.meta.stringToEnum(Typ, typ)) |etyp| {
            proto.type = etyp;
        } else {
            std.log.err("Something went wrong with protocol type: `{s}`\n", .{typ});
            proto.type = Typ.ERR;
            proto.action = Act.NONE;
            proto.id = "502";
            proto.body = "bad gateway";
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
    if (spl.next()) |id| {
        proto.id = id;
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
