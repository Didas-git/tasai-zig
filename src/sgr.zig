const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;

/// Not all SGR Attributes are supported by all terminals,
/// it's up for the developer to know which ones work and which don't.
pub const SGRAttribute = enum(u8) {
    Reset,
    Bold,
    Dim,
    Italic,
    Underline,
    Slow_Blink,
    Rapid_Blink,
    // Invert foreground and background colors
    Revert,
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
    Not_Reversed,
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

pub const SGRModifier = union(enum) {
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
    attribute: SGRAttribute,
};

pub inline fn verboseFormat(comptime text: []const u8, comptime opening_modifiers: []const SGRModifier, comptime closing_modifiers: []const SGRModifier) []const u8 {
    comptime {
        var open: []const u8 = &.{};
        var close: []const u8 = &.{};

        parseModifiers(&open, opening_modifiers);
        parseModifiers(&close, closing_modifiers);

        var temp: []const u8 = text;
        if (open.len > 0) temp = "\x1B[" ++ open[0 .. open.len - 1] ++ @as([]const u8, &.{'m'}) ++ temp;
        if (close.len > 0) temp = temp ++ "\x1B[" ++ close[0 .. close.len - 1] ++ @as([]const u8, &.{'m'});

        return temp;
    }
}

fn parseModifiers(buff: *[]const u8, modifiers: []const SGRModifier) void {
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
        0 => @intFromEnum(SGRAttribute.Default_Foreground_Color),
        10 => @intFromEnum(SGRAttribute.Default_Background_Color),
        else => @compileError("Only 0 and 10 are supported additives."),
    };

    return struct {
        const black: SGRCode = .{ .open = @intFromEnum(SGRAttribute.Foreground_Black) + additive, .close = close };
        const red: SGRCode = .{ .open = @intFromEnum(SGRAttribute.Foreground_Red) + additive, .close = close };
        const green: SGRCode = .{ .open = @intFromEnum(SGRAttribute.Foreground_Green) + additive, .close = close };
        const yellow: SGRCode = .{ .open = @intFromEnum(SGRAttribute.Foreground_Yellow) + additive, .close = close };
        const blue: SGRCode = .{ .open = @intFromEnum(SGRAttribute.Foreground_Blue) + additive, .close = close };
        const magenta: SGRCode = .{ .open = @intFromEnum(SGRAttribute.Foreground_Magenta) + additive, .close = close };
        const cyan: SGRCode = .{ .open = @intFromEnum(SGRAttribute.Foreground_Cyan) + additive, .close = close };
        const white: SGRCode = .{ .open = @intFromEnum(SGRAttribute.Foreground_White) + additive, .close = close };
        const bBlack: SGRCode = .{ .open = @intFromEnum(SGRAttribute.Foreground_Bright_Black) + additive, .close = close };
        const bRed: SGRCode = .{ .open = @intFromEnum(SGRAttribute.Foreground_Bright_Red) + additive, .close = close };
        const bGreen: SGRCode = .{ .open = @intFromEnum(SGRAttribute.Foreground_Bright_Green) + additive, .close = close };
        const bYellow: SGRCode = .{ .open = @intFromEnum(SGRAttribute.Foreground_Bright_Yellow) + additive, .close = close };
        const bBlue: SGRCode = .{ .open = @intFromEnum(SGRAttribute.Foreground_Bright_Blue) + additive, .close = close };
        const bMagenta: SGRCode = .{ .open = @intFromEnum(SGRAttribute.Foreground_Bright_Magenta) + additive, .close = close };
        const bCyan: SGRCode = .{ .open = @intFromEnum(SGRAttribute.Foreground_Bright_Cyan) + additive, .close = close };
        const bWhite: SGRCode = .{ .open = @intFromEnum(SGRAttribute.Foreground_Bright_White) + additive, .close = close };
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
///     - `inv` - Inverse (reverse)
/// - Colors:
///     - `f:<color>` - 3bit & 4bit Foreground Coloring (prefix with `b` for bright colors) ex: `f:bRed`, `f:blue`
///     - `f:n` - 8bit (0 - 255) Foreground Coloring
///     - `f:r,g,b` - 24bit (rgb) Foreground Coloring
///     - `f:#ffffff` - Hex code (24bit)
///     - `b:<color>` - 3bit & 4bit Background Coloring (prefix with `b` for bright colors)
///     - `b:n` - 8bit (0 - 255) Background Coloring
///     - `b:r,g,b` - 24bit (rgb) Background Coloring
///     - `b:#ffffff` - Hex code (24bit)
///     - `u:n` - 8bit (0 - 255) Underline Coloring
///     - `u:r,g,b` - 24bit (rgb) Underline Coloring
///     - `u:#ffffff` - Hex code (24bit)
pub inline fn parseString(comptime text: []const u8) []const u8 {
    comptime {
        var final_text: []const u8 = &.{};
        var stack: []const SGRAttribute = &.{};
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
                        stack = stack ++ @as([]const SGRAttribute, &.{SGRAttribute.Not_Bold_Or_Dim});
                        appendAttribute(&final_text, .Bold, previous_is_token);
                    },
                    'd' => {
                        stack = stack ++ @as([]const SGRAttribute, &.{SGRAttribute.Not_Bold_Or_Dim});
                        appendAttribute(&final_text, .Dim, previous_is_token);
                    },
                    'i' => {
                        stack = stack ++ @as([]const SGRAttribute, &.{SGRAttribute.Not_Italic});
                        appendAttribute(&final_text, .Italic, previous_is_token);
                    },
                    'u' => {
                        stack = stack ++ @as([]const SGRAttribute, &.{SGRAttribute.Not_Underlined});
                        appendAttribute(&final_text, .Underline, previous_is_token);
                    },
                    's' => {
                        stack = stack ++ @as([]const SGRAttribute, &.{SGRAttribute.Not_Crossed_Out});
                        appendAttribute(&final_text, .Crossed, previous_is_token);
                    },
                    'o' => {
                        stack = stack ++ @as([]const SGRAttribute, &.{SGRAttribute.Not_Overlined});
                        appendAttribute(&final_text, .Overlined, previous_is_token);
                    },
                    else => @compileError(fmt.comptimePrint("Invalid Token: '{s}'.", .{token})),
                },
                // Deduplication can and will be done eventually™️
                else => {
                    if (mem.eql(u8, token, "du")) {
                        stack = stack ++ @as([]const SGRAttribute, &.{SGRAttribute.Not_Underlined});
                        final_text = if (previous_is_token)
                            final_text[0 .. final_text.len - 1] ++ fmt.comptimePrint(";{d}m", .{@intFromEnum(SGRAttribute.Double_Underline)})
                        else
                            final_text ++ fmt.comptimePrint("\x1B[{d}m", .{@intFromEnum(SGRAttribute.Double_Underline)});
                    } else if (mem.eql(u8, token, "inv")) {
                        stack = stack ++ @as([]const SGRAttribute, &.{SGRAttribute.Not_Reversed});
                        appendAttribute(&final_text, .Invert, previous_is_token);
                    } else if (token[0] == 'f') {
                        // Skip `f` and `:`
                        const color_part = token[2..];
                        if (color_part.len < 1) @compileError("No valid color was passed.");
                        const possibly_a_int = fmt.parseInt(u8, &.{color_part[0]}, 10);

                        if (possibly_a_int == error.InvalidCharacter) {
                            // Handle hex as 24bit
                            if (color_part[0] == '#') {
                                append24BitColorFromHex(&final_text, hexToRgb(color_part[1..]), .Set_Foreground_Color, previous_is_token);
                                // Handle 4bit
                            } else {
                                const color = @field(ForegroundColors, color_part);
                                appendAttribute(&final_text, @enumFromInt(color.open), previous_is_token);
                            }
                            // Handle 8bit colors
                        } else if (color_part.len <= 3) {
                            append8BitColor(&final_text, color_part, .Set_Foreground_Color, previous_is_token);
                            // Handle 24 bit colors
                        } else {
                            append24BitColor(&final_text, color_part, .Set_Foreground_Color, previous_is_token);
                        }

                        stack = stack ++ @as([]const SGRAttribute, &.{SGRAttribute.Default_Foreground_Color});
                    } else if (token[0] == 'b') {
                        // Skip `b` and `:`
                        const color_part = token[2..];
                        if (color_part.len < 1) @compileError("No valid color was passed.");
                        const possibly_a_int = fmt.parseInt(u8, &.{color_part[0]}, 10);

                        if (possibly_a_int == error.InvalidCharacter) {
                            // Handle hex as 24bit
                            if (color_part[0] == '#') {
                                append24BitColorFromHex(&final_text, hexToRgb(color_part[1..]), .Set_Background_Color, previous_is_token);
                                // Handle 4bit
                            } else {
                                const color = @field(BackgroundColors, color_part);
                                appendAttribute(&final_text, @enumFromInt(color.open), previous_is_token);
                            }
                            // Handle 8bit colors
                        } else if (color_part.len <= 3) {
                            append8BitColor(&final_text, color_part, .Set_Background_Color, previous_is_token);
                            // Handle 24 bit colors
                        } else {
                            append24BitColor(&final_text, color_part, .Set_Background_Color, previous_is_token);
                        }

                        stack = stack ++ @as([]const SGRAttribute, &.{SGRAttribute.Default_Background_Color});
                    } else if (token[0] == 'u') {
                        // Skip `u` and `:`
                        const color_part = token[2..];
                        if (color_part.len < 1) @compileError("No valid color was passed.");
                        if (color_part[0] == '#') {
                            append24BitColorFromHex(&final_text, hexToRgb(color_part[1..]), .Set_Background_Color, previous_is_token);
                            // Handle 8bit colors
                        } else if (color_part.len <= 3) {
                            append8BitColor(&final_text, color_part, .Set_Underline_Color, previous_is_token);
                            // Handle 24bit colors
                        } else {
                            append24BitColor(&final_text, color_part, .Set_Underline_Color, previous_is_token);
                        }

                        stack = stack ++ @as([]const SGRAttribute, &.{SGRAttribute.Default_Underline_Color});
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

fn hexToRgb(hex: []const u8) []const u8 {
    var temp = [_]f32{ 0, 0, 0 };
    const color = fmt.parseInt(u32, hex, 16) catch @compileError("Failed to parse color");

    switch (hex.len) {
        2 => {
            temp[0] = @as(f32, (color & 0b1110_0000)) / 0b1110_0000;
            temp[1] = @as(f32, (color & 0b0001_1100)) / 0b0001_1100;
            temp[2] = @as(f32, (color & 0b0000_0011)) / 0b0000_0011;
        },
        3 => {
            temp[0] = @as(f32, (color & 0xF00)) / 0xF00;
            temp[1] = @as(f32, (color & 0x0F0)) / 0x0F0;
            temp[2] = @as(f32, (color & 0x00F)) / 0x00F;
        },
        4 => {
            temp[0] = @as(f32, (color & 0xF800)) / 0xF800;
            temp[1] = @as(f32, (color & 0x07E0)) / 0x07E0;
            temp[2] = @as(f32, (color & 0x001F)) / 0x001F;
        },
        6 => {
            temp[0] = @as(f32, (color & 0xFF_00_00)) / 0xFF_00_00;
            temp[1] = @as(f32, (color & 0x00_FF_00)) / 0x00_FF_00;
            temp[2] = @as(f32, (color & 0x00_00_FF)) / 0x00_00_FF;
        },
        else => @compileError("Invalid hex length."),
    }

    return &.{
        @round(@min(@max(temp[0], 0), 1) * 0xFF),
        @round(@min(@max(temp[1], 0), 1) * 0xFF),
        @round(@min(@max(temp[2], 0), 1) * 0xFF),
    };
}

fn appendAttribute(buff: *[]const u8, attribute: SGRAttribute, trim_last_byte: bool) void {
    buff.* = if (trim_last_byte)
        buff.*[0 .. buff.*.len - 1] ++ fmt.comptimePrint(";{d}m", .{@intFromEnum(attribute)})
    else
        buff.* ++ fmt.comptimePrint("\x1B[{d}m", .{@intFromEnum(attribute)});
}

fn append8BitColor(
    buff: *[]const u8,
    color_part: []const u8,
    open_code: SGRAttribute,
    trim_last_byte: bool,
) void {
    const color = fmt.parseInt(u8, color_part, 10) catch @compileError("Failed to parse color");
    buff.* = if (trim_last_byte)
        buff.*[0 .. buff.*.len - 1] ++ fmt.comptimePrint(";{d};5;{d}m", .{ @intFromEnum(open_code), color })
    else
        buff.* ++ fmt.comptimePrint("\x1B[{d};5;{d}m", .{ @intFromEnum(open_code), color });
}

fn append24BitColorFromHex(
    buff: *[]const u8,
    rgb: []const u8,
    open_code: SGRAttribute,
    trim_last_byte: bool,
) void {
    buff.* = if (trim_last_byte)
        buff.*[0 .. buff.*.len - 1] ++ fmt.comptimePrint(";{d};2;{d};{d};{d}m", .{ @intFromEnum(open_code), rgb[0], rgb[1], rgb[2] })
    else
        buff.* ++ fmt.comptimePrint("\x1B[{d};2;{d};{d};{d}m", .{ @intFromEnum(open_code), rgb[0], rgb[1], rgb[2] });
}

fn append24BitColor(
    buff: *[]const u8,
    color_part: []const u8,
    open_code: SGRAttribute,
    trim_last_byte: bool,
) void {
    // 11 is the max length of `rrr,ggg,bbb`
    if (color_part.len > 11) @compileError(fmt.comptimePrint("Invalid color: '{s}'", .{color_part}));

    var rgb: []const u8 = &.{};
    var iterator = mem.split(u8, color_part, ",");
    while (iterator.next()) |color_channel| {
        const channel_code = fmt.parseInt(u8, color_channel, 10) catch @compileError("Failed to parse color");
        rgb = rgb ++ @as([]const u8, &.{channel_code});
    }

    buff.* = if (trim_last_byte)
        buff.*[0 .. buff.*.len - 1] ++ fmt.comptimePrint(";{d};2;{d};{d};{d}m", .{ @intFromEnum(open_code), rgb[0], rgb[1], rgb[2] })
    else
        buff.* ++ fmt.comptimePrint("\x1B[{d};2;{d};{d};{d}m", .{ @intFromEnum(open_code), rgb[0], rgb[1], rgb[2] });
}
