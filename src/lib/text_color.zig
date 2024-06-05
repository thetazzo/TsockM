const fmt = @import("std").fmt;

/// ----------------------------------------------
///               Unitlity functions
/// ----------------------------------------------
/// Convert a number into a string
fn toString(num: u32) []const u8 {
    return fmt.comptimePrint("{d}", .{num});
}
/// Convert a hexadecimal representation of a color into its RGB components
fn hex_to_rgb(hex: []const u8) [3]u32 {
    const hexCode = if (hex[0] == '#') hex[1..] else hex;
    const hex_int = fmt.parseInt(u32, hexCode, 16) catch |err| @compileError("unable to parse hex due to " ++ @errorName(err));
    return [_]u32 {
    (hex_int >> 16) & 0xFF,
    (hex_int >> 8) & 0xFF,
        hex_int & 0xFF,
    };
}
/// ----------------------------------------------
/// Predefined color constants
/// ----------------------------------------------
pub const RESET = [_][]const u8{"0", "0"};
pub const GREEN = [_][]const u8{"32", "39"};
pub const GRAY  = [_][]const u8{"90", "39"};

/// ----------------------------------------------
/// Color painting functions
/// ----------------------------------------------
pub fn paint_green(str: []const u8)[]const u8 {
    return "\u{001B}[" ++ GREEN[0] ++ "m" ++ str ++ "\u{001B}[" ++ GREEN[1] ++ "m"; 
}

pub fn paint_light_gray(str: []const u8)[]const u8 {
    return "\u{001B}[" ++ GRAY[0] ++ "m" ++ str ++ "\u{001B}[" ++ GRAY[1] ++ "m"; 
}

pub fn paint_hex(hex: []const u8, str: []const u8) []const u8 {
    const rgb = hex_to_rgb(hex);
    return "\u{001B}[38;2;" ++ toString(rgb[0]) ++ ";" ++ toString(rgb[1]) ++ ";" ++ toString(rgb[2]) ++ "m" ++ str ++ "\u{001B}[m"; 
}
