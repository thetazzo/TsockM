const comm = @import("communication.zig");

pub fn NotFound(
    act: comm.Act,
    origin: comm.Origin,
    sender_id: []const u8,
    src_addr_str: []const u8,
    dest_addr_str: []const u8,
) comm.Protocol {
    return comm.Protocol{
        .type = .ERR,
        .action = act,
        .status = .NOT_FOUND,
        .origin = origin,
        .sender_id = sender_id,
        .src_addr = src_addr_str,
        .dest_addr = dest_addr_str,
        .body = "not found",
    };
}
