const FeEscapeSequence = @import("./control_codes.zig").FeEscapeSequence;
const Color = @import("./Color.zig");
const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;

/// Not all SGR Attributes are supported by all terminals,
/// it's up for the developer to know which ones work and which don't.
pub const Attribute = enum(u8) {
    Reset,
    Bold,
    Dim,
    Italic,
    Underline,
    Slow_Blink,
    Rapid_Blink,
    // Invert foreground and background colors
    Invert,
    Hide,
    Strike_Through,
    Default_Font,
    Font_1,
    Font_2,
    Font_3,
    Font_4,
    Font_5,
    Font_6,
    Font_7,
    Font_8,
    Font_9,
    Font_Gothic,
    /// In some terminals this acts as code 22 (not bold).
    Double_Underline,
    Not_Bold_Or_Dim,
    Not_Italic,
    Not_Underlined,
    Not_Blinking,
    Proportional_Spacing,
    Not_Inverted,
    Reveal,
    Not_Crossed_Out,
    Foreground_Black,
    Foreground_Red,
    Foreground_Green,
    Foreground_Yellow,
    Foreground_Blue,
    Foreground_Magenta,
    Foreground_Cyan,
    Foreground_White,
    /// Used for 8bit and 24bit (true color).
    Set_Foreground_Color,
    Default_Foreground_Color,
    Background_Black,
    Background_Red,
    Background_Green,
    Background_Yellow,
    Background_Blue,
    Background_Magenta,
    Background_Cyan,
    Background_White,
    /// Used for 8bit and 24bit (true color).
    Set_Background_Color,
    Default_Background_Color,
    Disable_Proportional_Spacing,
    Framed,
    Encircled,
    Overlined,
    Not_Framed_Or_Encircled,
    Not_Overlined,
    /// Follows the same convention as codes 38 and 48.
    /// Only supports 8bit and 24bit colors.
    Set_Underline_Color = 58,
    Default_Underline_Color,
    Ideogram_Underline_Or_Right_Side_Line,
    Ideogram_Double_Underline_Or_Double_Line_On_Right_Side,
    Ideogram_Overline_Or_Left_Side_Line,
    Ideogram_Double_Overline_Or_Double_Line_On_Left_Side,
    Ideogram_Stress_Marking,
    /// Disables all codes 60 to 64
    No_Ideogram_Attributes,
    Superscript = 73,
    Subscript,
    Not_Superscript_Or_Subscript,
    Foreground_Bright_Black = 90,
    Foreground_Bright_Red,
    Foreground_Bright_Green,
    Foreground_Bright_Yellow,
    Foreground_Bright_Blue,
    Foreground_Bright_Magenta,
    Foreground_Bright_Cyan,
    Foreground_Bright_White,
    Background_Bright_Black = 100,
    Background_Bright_Red,
    Background_Bright_Green,
    Background_Bright_Yellow,
    Background_Bright_Blue,
    Background_Bright_Magenta,
    Background_Bright_Cyan,
    Background_Bright_White,
};

pub const Modifier = union(enum) {
    color: union(enum) { foreground: union(enum) {
        @"8bit": u8,
        @"24bit": struct {
            r: u8,
            g: u8,
            b: u8,
        },
        normal: enum(u8) { Black = 30, Red, Green, Yellow, Blue, Magenta, Cyan, White },
        bright: enum(u8) { Black = 90, Red, Green, Yellow, Blue, Magenta, Cyan, White },
    }, background: union(enum) {
        @"8bit": u8,
        @"24bit": struct {
            r: u8,
            g: u8,
            b: u8,
        },
        normal: enum(u8) { Black = 40, Red, Green, Yellow, Blue, Magenta, Cyan, White },
        bright: enum(u8) { Black = 100, Red, Green, Yellow, Blue, Magenta, Cyan, White },
    }, underline: union(enum) {
        @"8bit": u8,
        @"24bit": struct {
            r: u8,
            g: u8,
            b: u8,
        },
    } },
    attribute: Attribute,
};

/// Due to the simplicity of this function the
/// 8bit and 24bit color attributes are invalid
pub fn get(attribute: Attribute) ![]const u8 {
    const is_invalid = switch (attribute) {
        .Set_Foreground_Color, .Set_Background_Color, .Set_Underline_Color => true,
        else => false,
    };

    if (is_invalid) return error.InvalidAttribute;

    var buf: [16]u8 = undefined;
    return std.fmt.bufPrint(&buf, FeEscapeSequence.CSI ++ "{d}m", .{@intFromEnum(attribute)}) catch unreachable;
}

pub inline fn verboseFormat(comptime text: []const u8, comptime opening_modifiers: []const Modifier, comptime closing_modifiers: []const Modifier) []const u8 {
    comptime {
        var open: []const u8 = &.{};
        var close: []const u8 = &.{};

        parseModifiers(&open, opening_modifiers);
        parseModifiers(&close, closing_modifiers);

        var temp: []const u8 = text;
        if (open.len > 0) temp = FeEscapeSequence.CSI ++ open[0 .. open.len - 1] ++ @as([]const u8, &.{'m'}) ++ temp;
        if (close.len > 0) temp = temp ++ FeEscapeSequence.CSI ++ close[0 .. close.len - 1] ++ @as([]const u8, &.{'m'});

        return temp;
    }
}

fn parseModifiers(buff: *[]const u8, modifiers: []const Modifier) void {
    for (modifiers) |attribute| {
        switch (attribute) {
            .attribute => |att| buff.* = buff.* ++ fmt.comptimePrint("{d};", .{@intFromEnum(att)}),
            .color => |apply_to| switch (apply_to) {
                .foreground => |foreground| switch (foreground) {
                    .normal => |color| buff.* = buff.* ++ fmt.comptimePrint("{d};", .{@intFromEnum(color)}),
                    .bright => |color| buff.* = buff.* ++ fmt.comptimePrint("{d};", .{@intFromEnum(color)}),
                    .@"8bit" => |color_code| buff.* = buff.* ++ fmt.comptimePrint("38;5;{d};", .{color_code}),
                    .@"24bit" => |color| buff.* = buff.* ++ fmt.comptimePrint("38;2;{d};{d};{d};", .{ color.r, color.g, color.b }),
                },
                // There is probably a way to avoid this duplication
                .background => |background| switch (background) {
                    .normal => |color| buff.* = buff.* ++ fmt.comptimePrint("{d};", .{@intFromEnum(color)}),
                    .bright => |color| buff.* = buff.* ++ fmt.comptimePrint("{d};", .{@intFromEnum(color)}),
                    .@"8bit" => |color_code| buff.* = buff.* ++ fmt.comptimePrint("48;5;{d};", .{color_code}),
                    .@"24bit" => |color| buff.* = buff.* ++ fmt.comptimePrint("48;2;{d};{d};{d};", .{ color.r, color.g, color.b }),
                },
                .underline => |underline| switch (underline) {
                    .@"8bit" => |color_code| buff.* = buff.* ++ fmt.comptimePrint("58;5;{d};", .{color_code}),
                    .@"24bit" => |color| buff.* = buff.* ++ fmt.comptimePrint("58;2;{d};{d};{d};", .{ color.r, color.g, color.b }),
                },
            },
        }
    }
}

const SGRCode = struct {
    open: u8,
    close: u8,
};
/// This structure does not follow naming conventions
/// as it is intended to be an internal map
fn CreateAvailableColors(comptime additive: u8) type {
    const close: u8 = switch (additive) {
        0 => @intFromEnum(Attribute.Default_Foreground_Color),
        10 => @intFromEnum(Attribute.Default_Background_Color),
        else => @compileError("Only 0 and 10 are supported additives."),
    };

    return struct {
        const black: SGRCode = .{ .open = @intFromEnum(Attribute.Foreground_Black) + additive, .close = close };
        const red: SGRCode = .{ .open = @intFromEnum(Attribute.Foreground_Red) + additive, .close = close };
        const green: SGRCode = .{ .open = @intFromEnum(Attribute.Foreground_Green) + additive, .close = close };
        const yellow: SGRCode = .{ .open = @intFromEnum(Attribute.Foreground_Yellow) + additive, .close = close };
        const blue: SGRCode = .{ .open = @intFromEnum(Attribute.Foreground_Blue) + additive, .close = close };
        const magenta: SGRCode = .{ .open = @intFromEnum(Attribute.Foreground_Magenta) + additive, .close = close };
        const cyan: SGRCode = .{ .open = @intFromEnum(Attribute.Foreground_Cyan) + additive, .close = close };
        const white: SGRCode = .{ .open = @intFromEnum(Attribute.Foreground_White) + additive, .close = close };
        const bBlack: SGRCode = .{ .open = @intFromEnum(Attribute.Foreground_Bright_Black) + additive, .close = close };
        const bRed: SGRCode = .{ .open = @intFromEnum(Attribute.Foreground_Bright_Red) + additive, .close = close };
        const bGreen: SGRCode = .{ .open = @intFromEnum(Attribute.Foreground_Bright_Green) + additive, .close = close };
        const bYellow: SGRCode = .{ .open = @intFromEnum(Attribute.Foreground_Bright_Yellow) + additive, .close = close };
        const bBlue: SGRCode = .{ .open = @intFromEnum(Attribute.Foreground_Bright_Blue) + additive, .close = close };
        const bMagenta: SGRCode = .{ .open = @intFromEnum(Attribute.Foreground_Bright_Magenta) + additive, .close = close };
        const bCyan: SGRCode = .{ .open = @intFromEnum(Attribute.Foreground_Bright_Cyan) + additive, .close = close };
        const bWhite: SGRCode = .{ .open = @intFromEnum(Attribute.Foreground_Bright_White) + additive, .close = close };
        const gray = bBlack;
        const grey = bBlack;
    };
}

const ForegroundColors = CreateAvailableColors(0);
const BackgroundColors = CreateAvailableColors(10);
/// Currently supported tokens:
/// - Normal Attributes:
///     - `r` - Smart Reset
///     - `b` - Bold
///     - `d` - Dim
///     - `i` - Italic
///     - `u` - Underline
///     - `s` - Strike through (crossed)
///     - `o` - Overlined
///     - `du` - Double Underline
///     - `inv` - Invert
/// - Colors:
///     - `f:<color>` - 3bit & 4bit Foreground Coloring (prefix with `b` for bright colors) ex: `f:bRed`, `f:blue`
///     - `f:n` - 8bit (0 - 255) Foreground Coloring
///     - `f:r,g,b` - 24bit (rgb) Foreground Coloring
///     - `f:#ffffff` - Hex code (24bit)
///     - `f:<color_space>:x,y,z` - 24bit color using specific color space
///     - `b:<color>` - 3bit & 4bit Background Coloring (prefix with `b` for bright colors)
///     - `b:n` - 8bit (0 - 255) Background Coloring
///     - `b:r,g,b` - 24bit (rgb) Background Coloring
///     - `b:#ffffff` - Hex code (24bit)
///     - `b:<color_space>:x,y,z` - 24bit color using specific color space
///     - `u:n` - 8bit (0 - 255) Underline Coloring
///     - `u:r,g,b` - 24bit (rgb) Underline Coloring
///     - `u:#ffffff` - Hex code (24bit)
///     - `u:<color_space>:x,y,z` - 24bit color using specific color space
///
/// Available color spaces are: `hsv`, `hsl` and `hsi`
pub inline fn parseString(comptime text: []const u8) []const u8 {
    comptime {
        var final_text: []const u8 = &.{};
        var stack: []const Attribute = &.{};
        var i: usize = 0;
        var previous_is_token: bool = false;
        // Maybe we should look into using the tokenizer in the std?
        while (i < text.len) : (i += 1) {
            const char = text[i];
            if (char != '<') {
                final_text = final_text ++ @as([]const u8, &.{char});
                previous_is_token = false;
                continue;
            }

            // If the user escaped the character then we don't read it as a token
            if (i != 0 and text[i - 1] == '\\') {
                final_text = final_text[0 .. final_text.len - 1] ++ @as([]const u8, &.{char});
                previous_is_token = false;
                continue;
            }

            i += 1;
            const start = i;

            while (true) {
                if (text[i] == '>') break;
                i = i + 1;
                if (i > text.len) @compileError("Wrongly formatted text.");
            }

            const token = text[start..i];
            switch (token.len) {
                0 => @compileError("Invalid Token."),
                1 => switch (token[0]) {
                    'r' => {
                        if (stack.len == 0) @compileError(fmt.comptimePrint("Extra reset tag found at index '{d}'", .{start + 1}));
                        appendAttribute(&final_text, stack[stack.len - 1], previous_is_token);
                        stack = stack[0 .. stack.len - 1];
                    },
                    'b' => {
                        stack = stack ++ @as([]const Attribute, &.{Attribute.Not_Bold_Or_Dim});
                        appendAttribute(&final_text, .Bold, previous_is_token);
                    },
                    'd' => {
                        stack = stack ++ @as([]const Attribute, &.{Attribute.Not_Bold_Or_Dim});
                        appendAttribute(&final_text, .Dim, previous_is_token);
                    },
                    'i' => {
                        stack = stack ++ @as([]const Attribute, &.{Attribute.Not_Italic});
                        appendAttribute(&final_text, .Italic, previous_is_token);
                    },
                    'u' => {
                        stack = stack ++ @as([]const Attribute, &.{Attribute.Not_Underlined});
                        appendAttribute(&final_text, .Underline, previous_is_token);
                    },
                    's' => {
                        stack = stack ++ @as([]const Attribute, &.{Attribute.Not_Crossed_Out});
                        appendAttribute(&final_text, .Strike_Through, previous_is_token);
                    },
                    'o' => {
                        stack = stack ++ @as([]const Attribute, &.{Attribute.Not_Overlined});
                        appendAttribute(&final_text, .Overlined, previous_is_token);
                    },
                    else => @compileError(fmt.comptimePrint("Invalid Token: '{s}'.", .{token})),
                },
                else => {
                    if (mem.eql(u8, token, "du")) {
                        stack = stack ++ @as([]const Attribute, &.{Attribute.Not_Underlined});
                        final_text = if (previous_is_token)
                            final_text[0 .. final_text.len - 1] ++ fmt.comptimePrint(";{d}m", .{@intFromEnum(Attribute.Double_Underline)})
                        else
                            final_text ++ fmt.comptimePrint(FeEscapeSequence.CSI ++ "{d}m", .{@intFromEnum(Attribute.Double_Underline)});
                    } else if (mem.eql(u8, token, "inv")) {
                        stack = stack ++ @as([]const Attribute, &.{Attribute.Not_Inverted});
                        appendAttribute(&final_text, .Invert, previous_is_token);
                    } else if (token[0] == 'f') {
                        parseColorAttribute(&final_text, &stack, token, .Set_Foreground_Color, .Default_Foreground_Color, previous_is_token);
                    } else if (token[0] == 'b') {
                        parseColorAttribute(&final_text, &stack, token, .Set_Background_Color, .Default_Background_Color, previous_is_token);
                    } else if (token[0] == 'u') {
                        parseColorAttribute(&final_text, &stack, token, .Set_Underline_Color, .Default_Underline_Color, previous_is_token);
                    } else {
                        @compileError(fmt.comptimePrint("Invalid Token: '{s}'.", .{token}));
                    }
                },
            }

            previous_is_token = true;
        }

        if (stack.len > 0) @compileError("Text has an unclosed token.");
        return final_text;
    }
}

fn parseColorAttribute(
    buf: *[]const u8,
    stack: *[]const Attribute,
    token: []const u8,
    opening_attribute: Attribute,
    closing_attribute: Attribute,
    trim_last_byte: bool,
) void {
    const color_part = token[2..];
    if (color_part.len < 1) @compileError("No valid color was passed.");
    const possibly_a_int = fmt.parseInt(u8, &.{color_part[0]}, 10);

    if (possibly_a_int == error.InvalidCharacter) {
        // Handle hex as 24bit
        if (color_part[0] == '#') {
            const color = Color.fromHex(color_part) catch @compileError(fmt.comptimePrint("Invalid hex color: '{s}'", .{color_part}));
            append24BitColor(buf, color, opening_attribute, trim_last_byte);
            // Handle other color spaces as 24bit
        } else if (color_part[0] == 'h') {
            const color_space = color_part[0..3];
            const values = color_part[4..];
            if (color_space[1] != 's' or (color_space[2] != 'l' and color_space[2] != 'i' and color_space[2] != 'v')) @compileError(fmt.comptimePrint("Invalid color space '{s}'", .{color_space}));

            var temp: [3]u8 = undefined;
            const upper_color_space = std.ascii.upperString(&temp, color_space);
            const parsed_color_space = parseStringArbitraryColorSpace(values);
            const color = @call(.auto, @field(Color, fmt.comptimePrint("from{s}", .{upper_color_space})), .{
                parsed_color_space[0],
                parsed_color_space[1],
                parsed_color_space[2],
                null,
            });

            append24BitColor(buf, color, opening_attribute, trim_last_byte);
            // Handle 4bit
        } else {
            const color = switch (opening_attribute) {
                .Set_Foreground_Color => @field(ForegroundColors, color_part),
                .Set_Background_Color => @field(BackgroundColors, color_part),
                .Set_Underline_Color => @compileError("Underline doesn't support 4bit colors."),
                else => @compileError("Invalid Attribute"),
            };

            appendAttribute(buf, @enumFromInt(color.open), trim_last_byte);
        }
        // Handle 8bit colors
    } else if (color_part.len <= 3) {
        append8BitColor(buf, color_part, opening_attribute, trim_last_byte);
        // Handle 24 bit colors
    } else {
        append24BitColor(buf, parseStringRGB(color_part), opening_attribute, trim_last_byte);
    }

    stack.* = stack.* ++ @as([]const Attribute, &.{closing_attribute});
}

fn appendAttribute(buff: *[]const u8, attribute: Attribute, trim_last_byte: bool) void {
    buff.* = if (trim_last_byte)
        buff.*[0 .. buff.*.len - 1] ++ fmt.comptimePrint(";{d}m", .{@intFromEnum(attribute)})
    else
        buff.* ++ fmt.comptimePrint(FeEscapeSequence.CSI ++ "{d}m", .{@intFromEnum(attribute)});
}

fn append8BitColor(
    buff: *[]const u8,
    color_part: []const u8,
    open_code: Attribute,
    trim_last_byte: bool,
) void {
    const color = fmt.parseInt(u8, color_part, 10) catch @compileError("Failed to parse color");
    buff.* = if (trim_last_byte)
        buff.*[0 .. buff.*.len - 1] ++ fmt.comptimePrint(";{d};5;{d}m", .{ @intFromEnum(open_code), color })
    else
        buff.* ++ fmt.comptimePrint(FeEscapeSequence.CSI ++ "{d};5;{d}m", .{ @intFromEnum(open_code), color });
}

fn append24BitColor(
    buff: *[]const u8,
    color: Color,
    open_code: Attribute,
    trim_last_byte: bool,
) void {
    buff.* = if (trim_last_byte)
        buff.*[0 .. buff.*.len - 1] ++ fmt.comptimePrint(";{d};2;{d};{d};{d}m", .{ @intFromEnum(open_code), color.red8Bit(), color.green8Bit(), color.blue8Bit() })
    else
        buff.* ++ fmt.comptimePrint(FeEscapeSequence.CSI ++ "{d};2;{d};{d};{d}m", .{ @intFromEnum(open_code), color.red8Bit(), color.green8Bit(), color.blue8Bit() });
}

fn parseStringRGB(
    color_part: []const u8,
) Color {
    // 11 is the max length of `rrr,ggg,bbb`
    if (color_part.len > 11) @compileError(fmt.comptimePrint("Invalid color: '{s}'", .{color_part}));

    const rgb = parseStringArbitraryColorSpace(color_part);

    return Color.init(rgb[0], rgb[1], rgb[2], null);
}

fn parseStringArbitraryColorSpace(color_part: []const u8) []const f64 {
    var pieces: []const f64 = &.{};
    var iterator = mem.split(u8, color_part, ",");

    while (iterator.next()) |color_channel| {
        const channel_code = fmt.parseFloat(f64, color_channel) catch @compileError(fmt.comptimePrint("Failed to parse color: '{s}'", .{color_channel}));
        pieces = pieces ++ @as([]const f64, &.{channel_code});
    }

    if (pieces.len > 3) @compileError("Invalid color part");
    return pieces;
}
