//! Codes prefixed with `C_` mean they are comptime-only
//! the non `C_` version is meant for runtime uses
//! Most of the time you will want to use the `C_` variant
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
/// Scroll Up
pub const SU = CommandWithAmount('S');
/// Scroll Down
pub const SD = CommandWithAmount('T');
/// Horizontal Vertical Position
pub const HVP = CommandWithRPositionalArgs('f');

/// Cursor Up
pub const C_CUU = CommandWithAmountComptime('A');
/// Cursor Down
pub const C_CUD = CommandWithAmountComptime('B');
/// Cursor Forward (right)
pub const C_CUF = CommandWithAmountComptime('C');
/// Cursor Back (left)
pub const C_CUB = CommandWithAmountComptime('D');
/// Cursor Next Line
pub const C_CNL = CommandWithAmountComptime('E');
/// Cursor Previous Line
pub const C_CPL = CommandWithAmountComptime('F');
/// Cursor Horizontal Absolute
pub const C_CHA = CommandWithAmountComptime('G');
/// Cursor Position
pub const C_CUP = CommandWithRPositionalArgsComptime('H');
/// Scroll Up
pub const C_SU = CommandWithAmountComptime('S');
/// Scroll Down
pub const C_SD = CommandWithAmountComptime('T');
/// Horizontal Vertical Position
pub const C_HVP = CommandWithRPositionalArgsComptime('f');

/// Clear from cursor to end of screen
pub const ED0 = FeEscapeSequence.CSI ++ "0J";
/// Clear from cursor to beginning of screen
pub const ED1 = FeEscapeSequence.CSI ++ "1J";
/// Clear entire screen
pub const ED2 = FeEscapeSequence.CSI ++ "2J";
/// Clear entire screen and delete lines in scroll buffer
pub const ED3 = FeEscapeSequence.CSI ++ "3J";

/// Clear from cursor to end of line
pub const EL0 = FeEscapeSequence.CSI ++ "0K";
/// Clear from cursor to beginning of line
pub const EL1 = FeEscapeSequence.CSI ++ "1K";
/// Clear entire line (doesn't change cursor position)
pub const EL2 = FeEscapeSequence.CSI ++ "2K";

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

fn CommandWithRPositionalArgs(char: u8) fn (buf: []u8, first: ?usize, second: ?usize) []const u8 {
    const fmt = FeEscapeSequence.CSI ++ "{d};{d}" ++ std.fmt.comptimePrint("{c}", .{char});
    return struct {
        fn temp(buf: []u8, first: ?usize, second: ?usize) []const u8 {
            const _first = first orelse 1;
            const _second = second orelse 1;
            return std.fmt.bufPrint(buf, fmt, .{ _first, _second }) catch unreachable;
        }
    }.temp;
}

fn CommandWithRPositionalArgsComptime(char: u8) fn (comptime first: ?usize, comptime second: ?usize) callconv(.Inline) []const u8 {
    const fmt = FeEscapeSequence.CSI ++ "{d};{d}" ++ std.fmt.comptimePrint("{c}", .{char});
    return struct {
        inline fn temp(comptime first: ?usize, comptime second: ?usize) []const u8 {
            const _first = first orelse 1;
            const _second = second orelse 1;
            return std.fmt.comptimePrint(fmt, .{ _first, _second });
        }
    }.temp;
}

fn CommandWithAmount(char: u8) fn (buf: []u8, count: ?usize) []const u8 {
    const fmt = FeEscapeSequence.CSI ++ "{d}" ++ std.fmt.comptimePrint("{c}", .{char});
    return struct {
        fn temp(buf: []u8, count: ?usize) []const u8 {
            const _count = count orelse 1;
            return std.fmt.bufPrint(buf, fmt, .{_count}) catch unreachable;
        }
    }.temp;
}

fn CommandWithAmountComptime(char: u8) fn (comptime count: ?usize) callconv(.Inline) []const u8 {
    const fmt = FeEscapeSequence.CSI ++ "{d}" ++ std.fmt.comptimePrint("{c}", .{char});
    return struct {
        inline fn temp(comptime count: ?usize) []const u8 {
            const _count = count orelse 1;
            return std.fmt.comptimePrint(fmt, .{_count});
        }
    }.temp;
}
