const std = @import("std");
const mem = std.mem;
const print = std.debug.print;

pub const ProtType = enum {
    REQ,
    RES,
};

pub const ProtAct = enum {
    COMM,
    MSG,
};

pub const Protocol = struct {
    type: ProtType,
    action: ProtAct,
    id: []const u8 = "",
    body: []const u8 = "",
    pub fn init(typ: ProtType, action: ProtAct, id: []const u8, bdy: []const u8) Protocol {
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
        switch (self.type) {
            ProtType.REQ => {
                try string.appendSlice("REQ");
            },
            ProtType.RES => {
                try string.appendSlice("RES");
            },
        }
        try string.appendSlice("::");
        switch (self.action) {
            ProtAct.COMM => {
                try string.appendSlice("COMM");
            },
            ProtAct.MSG => {
                try string.appendSlice("MSG");
            },
        }
        try string.appendSlice("::");
        try string.appendSlice(self.id);
        try string.appendSlice("::");
        try string.appendSlice(self.body);
        return string.items;
    }
    pub fn is_request(self: @This()) bool {
        return self.type == ProtType.REQ;
    }
    pub fn is_response(self: @This()) bool {
        return self.type == ProtType.RES;
    }
    pub fn is_action(self: @This(), act: ProtAct) bool {
        return self.action == act;
    }
};
pub fn protocol_from_str(str: []const u8) Protocol {
    var spl = mem.split(u8, str, "::");
    // [type]::[action]::[id]::[body]

    var proto = Protocol.init(ProtType.REQ, ProtAct.MSG, "", "");

    if (spl.next()) |typ| {
        if (mem.eql(u8, typ, "REQ")) {
            proto.type = ProtType.REQ;
        } else {
            proto.type = ProtType.RES;
        }
    }
    if (spl.next()) |act| {
        if (mem.eql(u8, act, "COMM")) {
            proto.action = ProtAct.COMM;
        } else {
            proto.action = ProtAct.MSG;
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
