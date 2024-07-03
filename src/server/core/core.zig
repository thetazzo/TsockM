pub const Peer = @import("peer.zig").Peer;
pub const sc = @import("server.zig");
pub const SharedData = @import("shared-data.zig").SharedData;

test {
    _ = @import("server.test.zig");
    _ = @import("peer-pool.zig");
    @import("std").testing.refAllDecls(@This());
}
