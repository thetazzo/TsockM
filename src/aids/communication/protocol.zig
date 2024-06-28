const std = @import("std");
const tc = @import("../text_color.zig");
const comm = @import("communication.zig");
const Logging = @import("../logging.zig");
const mem = std.mem;
const print = std.debug.print;

// TODO: make this part of the protocol
//       as of right now this is only used
//       on transmition of servercationsc
// TODO: allow protocols to specify how they
//       should be transmitted and to where
//       they should be transmitted
pub const TransmitionMode = enum {
    UNICAST,
    BROADCAST,
};
/// Protocol structure
///     shape: [type]::[action]::[status_code]::[sender_id]::[src_addr]::[dest_addr]::[body]
pub const Protocol = struct {
    type: comm.Typ,
    action: comm.Act,
    status_code: comm.Status,
    sender_id: []const u8,
    body: []const u8,
    src_addr: []const u8,
    dest_addr: []const u8,
    pub fn dump(self: @This(), log_level: Logging.Level) void {
        if (log_level == Logging.Level.SILENT) return;

        if (log_level == Logging.Level.COMPACT) {
            print("{s}\n", .{self.asStr()});
        } else {
            // TODO: Logging.filter
            //if (log_level == Logging.Level.REQ and self.type != Typ.REQ) return;

            print("====================================\n", .{});
            print(" {s}: `{s}` {{{s}}}                 \n", .{
                comm.typAsStr(self.type),
                @tagName(self.action),
                self.sender_id,
            });
            if (log_level == Logging.Level.DEV) {
                print("------------------------------------\n", .{});
                print(" Protocol \n", .{});
                print("     type:      `{s}`\n", .{@tagName(self.type)});
                print("     action:    `{s}`\n", .{@tagName(self.action)});
                print("     status_code:  `{s}`\n", .{comm.statusAsStr(self.status_code)});
                print("     sender_id: `{s}`\n", .{self.sender_id});
                print("     src_addr:  `{s}`\n", .{self.src_addr});
                print("     dest_addr:  `{s}`\n", .{self.dest_addr});
                print("     body:      `{s}`\n", .{self.body});
            }
            print("====================================\n", .{});
        }
    }
    pub fn asStr(self: @This()) []const u8 {
        var buf: [2048]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        var string = std.ArrayList(u8).init(fba.allocator());
        _ = string.appendSlice(@tagName(self.type)) catch "OutOfMemory";
        _ = string.appendSlice("::") catch "OutOfMemory";
        _ = string.appendSlice(@tagName(self.action)) catch "OutOfMemory";
        _ = string.appendSlice("::") catch "OutOfMemory";
        _ = string.appendSlice(comm.statusAsStr(self.status_code)) catch "OutOfMemory";
        _ = string.appendSlice("::") catch "OutOfMemory";
        _ = string.appendSlice(self.sender_id) catch "OutOfMemory";
        _ = string.appendSlice("::") catch "OutOfMemory";
        _ = string.appendSlice(self.src_addr) catch "OutOfMemory";
        _ = string.appendSlice("::") catch "OutOfMemory";
        _ = string.appendSlice(self.dest_addr) catch "OutOfMemory";
        _ = string.appendSlice("::") catch "OutOfMemory";
        _ = string.appendSlice(self.body) catch "OutOfMemory";
        return string.items;
    }
    pub fn isRequest(self: @This()) bool {
        return self.type == .REQ;
    }

    pub fn isResponse(self: @This()) bool {
        return self.type == .RES;
    }

    pub fn isAction(self: @This(), act: comm.Act) bool {
        return self.action == act;
    }
    /// returns 1 when stream is closed
    pub fn transmit(self: @This(), stream: std.net.Stream) !void {
        _ = try stream.write(self.asStr());
    }

    pub fn eql(self: @This(), prot: Protocol) bool {
        if (prot.type != self.type) {
            std.log.err(
                "protocols `type` are not equal. Expected `{s}`, Found `{s}`",
                .{ @tagName(self.type), @tagName(prot.type) },
            );
            return false;
        }
        if (prot.action != self.action) {
            std.log.err(
                "protocols `action` are not equal. Expected `{s}`, Found `{s}`",
                .{ @tagName(self.action), @tagName(prot.action) },
            );
            return false;
        }
        if (prot.status_code != self.status_code) {
            std.log.err(
                "protocols `status_code` are not equal. Expected `{s}`, Found `{s}`",
                .{ @tagName(self.status_code), @tagName(prot.status_code) },
            );
            return false;
        }
        if (!std.mem.eql(u8, prot.sender_id, self.sender_id)) {
            std.log.err(
                "protocols `sender_id` are not equal. Expected `{s}`, Found `{s}`",
                .{ self.sender_id, prot.sender_id },
            );
            return false;
        }
        if (!std.mem.eql(u8, prot.src_addr, self.src_addr)) {
            std.log.err(
                "protocols `src_addr` are not equal. Expected `{s}`, Found `{s}`",
                .{ self.src_addr, prot.src_addr },
            );
            return false;
        }
        if (!std.mem.eql(u8, prot.dest_addr, self.dest_addr)) {
            std.log.err(
                "protocols `dest_addr` are not equal. Expected `{s}`, Found `{s}`",
                .{ self.dest_addr, prot.dest_addr },
            );
            return false;
        }
        if (!std.mem.eql(u8, prot.body, self.body)) {
            std.log.err(
                "protocols `body` are not equal. Expected `{s}`, Found `{s}`",
                .{ self.body, prot.body },
            );
            return false;
        }
        return true;
    }
};

pub fn collect(allocator: mem.Allocator, stream: std.net.Stream) !Protocol {
    var buf: [1024]u8 = undefined;
    _ = try stream.read(&buf);
    const resps = mem.sliceTo(&buf, 170);
    const respss = try std.fmt.allocPrint(allocator, "{s}", .{resps});
    const resp = Protocol.fromStr(respss);
    return resp;
}

test "protocol as string" {
    var p: Protocol = Protocol{
        .type = .REQ,
        .action = .NONE,
        .status_code = .OK,
        .sender_id = "tester",
        .src_addr = "test",
        .dest_addr = "test",
        .body = "",
    };
    try std.testing.expectEqualStrings("REQ::NONE::200::tester::test::test::", p.asStr());
}
