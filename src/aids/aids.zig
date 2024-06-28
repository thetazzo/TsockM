pub const Logging = @import("logging.zig");
pub const proto = @import("protocol.zig");
pub const cmn = @import("common.zig");
pub const TextColor = @import("text_color.zig");
pub const Assert = @import("assert.zig");
const Commander_ = @import("commander.zig");
const Actioner_ = @import("actioner.zig");

pub const v2 = struct {
    pub const comm = @import("./communication/communication.zig");
};

pub const Stab = struct {
    pub const Commander = Commander_.Commander;
    pub const Command = Commander_.Command;
    pub const Actioner = Actioner_.Actioner;
    pub const Action = Actioner_.Action;
    pub const Act = Actioner_.Act;
    pub const parseAct = Actioner_.parseAct;
};

test "AIDS" {
    _ = @import("communication/communication.zig");
    _ = @import("actioner.zig");
    @import("std").testing.refAllDecls(@This());
}
