const FeEscapeSequence = @import("./ansi.zig").FeEscapeSequence;
const std = @import("std");

pub const CUU = CommandWithAmount('A');
pub const CUD = CommandWithAmount('B');
pub const CUF = CommandWithAmount('C');
pub const CUB = CommandWithAmount('D');
pub const CNL = CommandWithAmount('E');
pub const CPL = CommandWithAmount('F');
pub const CHA = CommandWithAmount('G');
pub const CUP = CommandWithRPositionalArgs('H');
pub const ED = CommandWithAmount('J');
pub const EL = CommandWithAmount('K');
pub const SU = CommandWithAmount('S');
pub const SD = CommandWithAmount('T');
pub const HVP = CommandWithRPositionalArgs('f');

pub const AUXON = FeEscapeSequence.CSI ++ "5i";
pub const AUXOFF = FeEscapeSequence.CSI ++ "4i";
pub const DSR = FeEscapeSequence.CSI ++ "6n";

pub const SCP = FeEscapeSequence.CSI ++ "s";
pub const SCOSC = CommandWithRPositionalArgs('s');
pub const RCP = FeEscapeSequence.CSI ++ "u";
pub const CUS = FeEscapeSequence.CSI ++ "?25h";
pub const CUH = FeEscapeSequence.CSI ++ "?25l";

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
