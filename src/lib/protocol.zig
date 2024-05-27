const std = @import("std");
const mem = std.mem;
const print = std.debug.print;

pub const Typ = enum {
    REQ,
    RES,
    ERR,
    NONE,
};

pub const Act = enum {
    COMM,
    COMM_END,
    MSG,
    NONE,
};

pub const Protocol = struct {
    type: Typ = Typ.NONE,
    action: Act = Act.NONE,
    id: []const u8 = "",
    body: []const u8 = "",
    pub fn init(typ: Typ, action: Act, id: []const u8, bdy: []const u8) Protocol {
        return Protocol{
            .type = typ,
            .action = action,
            .id = id,
            .body = bdy,
        };
    }
    pub fn dump(self: @This()) void {
        print("------------------------------------\n", .{});
        print("Protocol {{\n", .{});
        print("    type: `{s}`\n", .{@tagName(self.type)});
        print("    action: `{s}`\n", .{@tagName(self.action)});
        print("    id: `{s}`\n", .{self.id});
        print("    body: `{s}`\n", .{self.body});
        print("}}\n", .{});
        print("------------------------------------\n", .{});
    }
    pub fn as_str(self: @This()) ![]const u8 {
        var buf: [256]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        var string = std.ArrayList(u8).init(fba.allocator());
        // Consider using the json fomrat instead
        // try std.json.stringify(x, .{}, string.writer());
        try string.appendSlice(@tagName(self.type));
        try string.appendSlice("::");
        try string.appendSlice(@tagName(self.action));
        try string.appendSlice("::");
        try string.appendSlice(self.id);
        try string.appendSlice("::");
        try string.appendSlice(self.body);
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
pub fn protocol_from_str(str: []const u8) Protocol {
    var spl = mem.split(u8, str, "::");
    // [type]::[action]::[id]::[body]

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
    if (spl.next()) |bdy| {
        proto.body = bdy;
    }
    return proto;
}
