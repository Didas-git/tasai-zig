const std = @import("std");
const ascii = std.ascii;

/// https://en.wikipedia.org/wiki/ANSI_escape_code#Fe_Escape_sequences
pub const FeEscapeSequence = struct {
    pub const SS2 = sequence('N');
    pub const SS3 = sequence('O');
    pub const DCS = sequence('P');
    pub const CSI = sequence('[');
    pub const ST = sequence('\\');
    pub const OSC = sequence(']');
    pub const SOS = sequence('X');
    pub const PM = sequence('^');
    pub const APC = sequence('_');
};

/// https://en.wikipedia.org/wiki/ISO/IEC_2022#Other_control_functions
pub const FsEscapeSequence = struct {
    pub const DMI = sequence('`');
    pub const INT = sequence('a');
    pub const EMI = sequence('b');
    pub const RIS = sequence('c');
    pub const CMD = sequence('d');
    pub const LS2 = sequence('n');
    pub const LS3 = sequence('o');
    pub const LS3R = sequence('|');
    pub const LS2R = sequence('}');
    pub const LS1R = sequence('~');
};

/// https://en.wikipedia.org/wiki/ANSI_escape_code#Fp_Escape_sequences
pub const FpEscapeSequence = struct {
    pub const DECSC = sequence('7');
    pub const DECRC = sequence('8');
};

inline fn sequence(comptime char: u8) []const u8 {
    return std.fmt.comptimePrint("{c}{c}", .{ ascii.control_code.esc, char });
}

fn parseControlCode(str: []const u8) usize {
    var i: usize = 0;
    switch (str[i]) {
        ascii.control_code.esc => {
            i += 1;
            switch (str[i]) {
                // CSI
                '[' => {
                    while (true) : (i += 1) {
                        if (str[i] == 'm') {
                            i += 1;
                            break;
                        }
                    }
                },
                // OSC
                ']' => {
                    while (true) : (i += 1) {
                        if (str[i] == ascii.control_code.esc and str[i + 1] == '\\') {
                            i += 2;
                            break;
                        }
                    }
                },
                // TODO: See if optimizations can be done here
                'N', 'O', 'P', '\\', 'X', '^', '_' => {},
                else => {},
            }
        },
        ' ',
        ascii.control_code.ht,
        ascii.control_code.lf,
        ascii.control_code.cr,
        ascii.control_code.vt,
        ascii.control_code.ff,
        => return 0,
        else => return 1,
    }

    return i;
}

pub inline fn comptimeStrip(comptime str: []const u8) []const u8 {
    comptime {
        var buf: []const u8 = &.{};

        var i: usize = 0;
        while (i < str.len) : (i += 1) {
            if (ascii.isControl(str[i])) {
                i += parseControlCode(str[i..]);
            }

            buf = buf ++ .{str[i]};
        }

        return buf;
    }
}

pub fn strip(allocator: std.mem.Allocator, str: []const u8) ![]const u8 {
    var arr = std.ArrayList(u8).init(allocator);

    var i: usize = 0;
    while (i < str.len) : (i += 1) {
        if (ascii.isControl(str[i])) {
            i += parseControlCode(str[i..]);
        }

        try arr.append(str[i]);
    }

    return arr.toOwnedSlice();
}
