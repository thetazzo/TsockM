const std = @import("std");
const mem = std.mem;
const print = std.debug.print;

pub const ProtocolType = enum {
    REQ,
    RES,
};

pub const Protocol = struct {
    type: ProtocolType,
    action: []const u8 = "",
    id: []const u8 = "",
    body: []const u8 = "",
    pub fn init(typ: ProtocolType, action: []const u8, id: []const u8, bdy: []const u8) Protocol {
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
        print("    type: `{d}`\n", .{@intFromEnum(self.type)});
        print("    action: `{s}`\n", .{self.action});
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
        switch (self.type) {
            ProtocolType.REQ => {
                try string.appendSlice("REQ");
            },
            ProtocolType.RES => {
                try string.appendSlice("RES");
            },
        }
        try string.appendSlice("::");
        try string.appendSlice(self.action);
        try string.appendSlice("::");
        try string.appendSlice(self.id);
        try string.appendSlice("::");
        try string.appendSlice(self.body);
        return string.items;
    }
    pub fn is_request(self: @This()) bool {
        return self.type == ProtocolType.REQ;
    }
    pub fn is_response(self: @This()) bool {
        return self.type == ProtocolType.RES;
    }
    pub fn is_action(self: @This(), act: []const u8) bool {
        return mem.eql(u8, self.action, act);
    }
};
pub fn protocol_from_str(str: []const u8) Protocol {
    var spl = mem.split(u8, str, "::");
    // [type]::[action]::[id]::[body]

    var proto = Protocol.init(ProtocolType.REQ, "", "", "");

    if (spl.next()) |typ| {
        if (mem.eql(u8, typ, "REQ")) {
            proto.type = ProtocolType.REQ;
        } else {
            proto.type = ProtocolType.RES;
        }
    }
    if (spl.next()) |act| {
        proto.action = act;
    }
    if (spl.next()) |id| {
        proto.id = id;
    }
    if (spl.next()) |bdy| {
        proto.body = bdy;
    }
    return proto;
}
