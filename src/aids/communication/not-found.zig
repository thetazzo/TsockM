const comm = @import("communication.zig");

pub fn NotFound(src_addr_str: []const u8, dest_addr_str: []const u8, sender_id: []const u8, act: comm.Act) comm.Protocol {
    return comm.Protocol{
        .type = .ERR,
        .action = act,
        .status_code = .NOT_FOUND,
        .sender_id = sender_id,
        .src_addr = src_addr_str,
        .dest_addr = dest_addr_str,
        .body = "not found",
    };
}
