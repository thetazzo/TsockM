const std = @import("std");
const rl = @import("raylib");

pub const Message = struct {
    author: []const u8,
    text: []const u8,
};

rec: rl.Rectangle = undefined,
messages: std.ArrayList(Message) = undefined,
pub fn setRec(self: *@This(), x: f32, y: f32, w: f32, h: f32) rl.Rectangle {
    self.rec = rl.Rectangle.init(x, y, w, h);
    return self.rec;
}
pub fn allocMessages(self: *@This(), allocator: std.mem.Allocator) void  {
    self.messages = std.ArrayList(Message).init(allocator);
}
pub fn isClicked(self: @This()) bool {
    if (rl.checkCollisionPointRec(rl.getMousePosition(), self.rec)) {
        if (rl.isMouseButtonPressed(.mouse_button_left)) {
            return true;
        }
    }
    return false;
}
pub fn clean(self: *@This()) [256]u8 {
    _ = self;
    std.log.err("not implemented", .{});
    std.posix.exit(1);
}
pub fn render(self: *@This(), allocator: std.mem.Allocator, font: rl.Font, font_size: f32, frame_counter: usize) !void {
    _ = frame_counter;
    rl.drawRectangleRounded(self.rec, 0.05, 0, rl.Color.black);
    const padd = 40;
    for (self.messages.items, 0..) |msg, i| {
        const msgg = try std.fmt.allocPrintZ(allocator, "{s}: {s}", .{msg.author, msg.text});
        defer allocator.free(msgg);
        const msg_height = rl.measureTextEx(font, msgg, font_size, 0).y;
        const msg_pos = rl.Vector2{.x = self.rec.x + padd, .y = self.rec.y + padd + msg_height*@as(f32, @floatFromInt(i))};
        rl.drawTextEx(font, msgg, msg_pos, font_size, 0, rl.Color.ray_white);
    }
}
