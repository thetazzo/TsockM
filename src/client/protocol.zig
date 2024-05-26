const std = @import("std");
const mem = std.mem;
const print = std.debug.print;

pub const Protocol = struct {
    type: []const u8 = "",
    action: []const u8 = "",
    id: []const u8 = "",
    body: []const u8 = "",
    pub fn init(typ: []const u8, action: []const u8, id: []const u8, bdy: []const u8) Protocol {
        return Protocol{
            .type = typ,
            .action = action,
            .id = id,
            .body = bdy,
        };
    }
    pub fn setType(self: *@This(), val: []const u8) *Protocol {
        self.type = val;
        return self;
    }
    pub fn dump(self: @This()) void {
        print("------------------------------------\n", .{});
        print("Protocol {{\n", .{});
        print("    type: `{s}`\n", .{self.type});
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
        try string.appendSlice(self.type);
        try string.appendSlice("::");
        try string.appendSlice(self.action);
        try string.appendSlice("::");
        try string.appendSlice(self.id);
        try string.appendSlice("::");
        try string.appendSlice(self.body);
        return string.items;
    }
};
pub fn protocol_from_str(str: []const u8) Protocol {
    var spl = mem.split(u8, str, "::");
    // [type]::[action]::[id]::[body]

    var proto = Protocol.init("", "", "", "");

    if (spl.next()) |typ| {
        proto.type = typ;
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
