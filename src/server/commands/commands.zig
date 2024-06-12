pub const EXIT_SERVER = @import("exit-server.zig").COMMAND;
pub const PRINT_SERVER_STATS = @import("print-server-stats.zig").COMMAND;
pub const LIST_ACTIVE_PEERS = @import("list-active-peers.zig").COMMAND;
pub const KILL_PEER = @import("kill-peer.zig").COMMAND;
pub const PING = @import("ping.zig").COMMAND;
pub const CLEAR_SCREEN = @import("clear-screen.zig").COMMAND;
pub const CLEAN_PEER_POOL = @import("clean-peer-pool.zig").COMMAND;
pub const PRINT_PROGRAM_USAGE = @import("print-program-usage.zig").COMMAND;
const mute = @import("mute.zig");
pub const MUTE = mute.COMMAND_MUTE;
pub const UNMUTE = mute.COMMAND_UNMUTE;

