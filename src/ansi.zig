const std = @import("std");

/// https://en.wikipedia.org/wiki/C0_and_C1_control_codes
pub const ControlCode = struct {
    pub const NUL = 0;
    pub const SOH = 1;
    pub const STX = 2;
    pub const ETX = 3;
    pub const EOT = 4;
    pub const ENQ = 5;
    pub const ACK = 6;
    pub const BEL = 7;
    pub const BS = 8;
    pub const HT = 9;
    pub const LF = 10;
    pub const VT = 11;
    pub const FF = 12;
    pub const CR = 13;
    pub const SO = 14;
    pub const SI = 15;
    pub const DLE = 16;
    pub const XON = 17;
    pub const TAPE = 18;
    pub const XOFF = 19;
    pub const NTAPE = 20;
    pub const NAK = 21;
    pub const SYN = 22;
    pub const ETB = 23;
    pub const CAN = 24;
    pub const EM = 25;
    pub const SUB = 26;
    pub const ESC = 27;
    pub const FS = 28;
    pub const GS = 29;
    pub const RS = 30;
    pub const US = 31;
    pub const SP = 32;
    pub const DEL = 127;
    pub const PAD = 128;
    pub const HOP = 129;
    pub const BPH = 130;
    pub const NBH = 131;
    pub const IND = 132;
    pub const NEL = 133;
    pub const SSA = 134;
    pub const ESA = 135;
    pub const HTS = 136;
    pub const HTJ = 137;
    pub const VTS = 138;
    pub const PLD = 139;
    pub const PLU = 140;
    pub const RI = 141;
    pub const SS2 = 142;
    pub const SS3 = 143;
    pub const DCS = 144;
    pub const PU1 = 145;
    pub const PU2 = 146;
    pub const STS = 147;
    pub const CCH = 148;
    pub const MW = 149;
    pub const SPA = 150;
    pub const EPA = 151;
    pub const SOS = 152;
    pub const SGC = 153;
    pub const SCI = 154;
    pub const CSI = 155;
    pub const ST = 156;
    pub const OSC = 157;
    pub const PM = 158;
    pub const APC = 159;
};

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
    return std.fmt.comptimePrint("{c}{c}", .{ ControlCode.ESC, char });
}

/// CR, LF, and other whitespace characters are ignored
pub fn isControlCode(char: u8) bool {
    return !std.ascii.isWhitespace(char) and (char <= ControlCode.SP or (char >= ControlCode.DEL and char <= ControlCode.APC));
}

fn parseControlCode(str: []const u8) usize {
    var i: usize = 0;
    if (str[i] == ControlCode.ESC) {
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
                    if (str[i] == ControlCode.ESC and str[i + 1] == '\\') {
                        i += 2;
                        break;
                    }
                }
            },
            // TODO: See if optimizations can be done here
            'N', 'O', 'P', '\\', 'X', '^', '_' => {},
            else => {},
        }
    }

    return i;
}

pub inline fn comptimeStrip(comptime str: []const u8) []const u8 {
    comptime {
        var buf: []const u8 = &.{};

        var i: usize = 0;
        while (i < str.len) : (i += 1) {
            if (isControlCode(str[i])) {
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
        if (isControlCode(str[i])) {
            i += parseControlCode(str[i..]);
        }

        try arr.append(str[i]);
    }

    return arr.toOwnedSlice();
}
