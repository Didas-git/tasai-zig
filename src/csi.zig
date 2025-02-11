const FeEscapeSequence = @import("./ansi.zig").FeEscapeSequence;
const std = @import("std");

/// Cursor Up
pub const CUU = CommandWithAmount('A');
/// Cursor Down
pub const CUD = CommandWithAmount('B');
/// Cursor Forward (right)
pub const CUF = CommandWithAmount('C');
/// Cursor Back (left)
pub const CUB = CommandWithAmount('D');
/// Cursor Next Line
pub const CNL = CommandWithAmount('E');
/// Cursor Previous Line
pub const CPL = CommandWithAmount('F');
/// Cursor Horizontal Absolute
pub const CHA = CommandWithAmount('G');
/// Cursor Position
pub const CUP = CommandWithRPositionalArgs('H');
/// Erase in Display
pub const ED = CommandWithAmount('J');
/// Erase in Line
pub const EL = CommandWithAmount('K');
/// Scroll Up
pub const SU = CommandWithAmount('S');
/// Scroll Down
pub const SD = CommandWithAmount('T');
/// Horizontal Vertical Position
pub const HVP = CommandWithRPositionalArgs('f');

pub const AUXON = FeEscapeSequence.CSI ++ "5i";
pub const AUXOFF = FeEscapeSequence.CSI ++ "4i";
/// Device Status Report
pub const DSR = FeEscapeSequence.CSI ++ "6n";

/// Save Current Cursor Position
pub const SCP = FeEscapeSequence.CSI ++ "s";
/// Save Current Cursor Position Split Screen
pub const SCOSC = CommandWithRPositionalArgs('s');
/// Restore Saved Cursor Position
pub const RCP = FeEscapeSequence.CSI ++ "u";
/// Show Cursor
pub const CUS = FeEscapeSequence.CSI ++ "?25h";
/// Hide Cursor
pub const CUH = FeEscapeSequence.CSI ++ "?25l";

/// Select Graphic Rendition
pub const SGR = @import("./sgr.zig");

fn CommandWithRPositionalArgs(char: u8) fn (first: ?usize, second: ?usize) []const u8 {
    const fmt = FeEscapeSequence.CSI ++ "{d};{d}" ++ std.fmt.comptimePrint("{c}", .{char});
    return struct {
        fn temp(first: ?usize, second: ?usize) []const u8 {
            const _first = first orelse 1;
            const _second = second orelse 1;
            var buf: [32]u8 = undefined;
            return std.fmt.bufPrint(&buf, fmt, .{ _first, _second }) catch unreachable;
        }
    }.temp;
}

fn CommandWithAmount(char: u8) fn (count: ?usize) []const u8 {
    const fmt = FeEscapeSequence.CSI ++ "{d}" ++ std.fmt.comptimePrint("{c}", .{char});
    return struct {
        fn temp(count: ?usize) []const u8 {
            const _count = count orelse 1;
            var buf: [16]u8 = undefined;
            return std.fmt.bufPrint(&buf, fmt, .{_count}) catch unreachable;
        }
    }.temp;
}
