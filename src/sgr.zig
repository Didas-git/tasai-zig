const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;

/// Not all SGR Attributes are supported by all terminals,
/// it's up for the developer to know which ones work and which don't.
const SGRAttribute = enum(u8) {
    Reset,
    Bold,
    Dim,
    Italic,
    Underline,
    Slow_Blink,
    Rapid_Blink,
    Invert,
    Hide,
    Strikethrough,
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

const SGRModifier = union(enum) {
    Color: union(enum) { Foreground: union(enum) {
        @"8bit": u8,
        @"24bit": struct {
            r: u8,
            g: u8,
            b: u8,
        },
        Normal: enum(u8) { Black = 30, Red, Green, Yellow, Blue, Magenta, Cyan, White },
        Bright: enum(u8) { Black = 90, Red, Green, Yellow, Blue, Magenta, Cyan, White },
    }, Background: union(enum) {
        @"8bit": u8,
        @"24bit": struct {
            r: u8,
            g: u8,
            b: u8,
        },
        Normal: enum(u8) { Black = 40, Red, Green, Yellow, Blue, Magenta, Cyan, White },
        Bright: enum(u8) { Black = 100, Red, Green, Yellow, Blue, Magenta, Cyan, White },
    }, Underline: union(enum) {
        @"8bit": u8,
        @"24bit": struct {
            r: u8,
            g: u8,
            b: u8,
        },
    } },
    Attribute: SGRAttribute,
};

pub fn format(comptime text: []const u8, comptime opening_modifiers: []const SGRModifier, comptime closing_modifiers: []const SGRModifier) []const u8 {
    comptime var open: []const u8 = &.{};
    comptime var close: []const u8 = &.{};

    comptime parseModifiers(&open, opening_modifiers);
    comptime parseModifiers(&close, closing_modifiers);

    comptime var temp: []const u8 = text;
    if (open.len > 0) temp = "\x1B[" ++ open[0 .. open.len - 1] ++ @as([]const u8, &.{'m'}) ++ temp;
    if (close.len > 0) temp = temp ++ "\x1B[" ++ close[0 .. close.len - 1] ++ @as([]const u8, &.{'m'});

    return temp;
}

fn parseModifiers(buff: *[]const u8, modifiers: []const SGRModifier) void {
    for (modifiers) |attribute| {
        switch (attribute) {
            .Attribute => |att| buff.* = buff.* ++ fmt.comptimePrint("{d};", .{@intFromEnum(att)}),
            .Color => |apply_to| switch (apply_to) {
                .Foreground => |foreground| switch (foreground) {
                    .Normal => |color| buff.* = buff.* ++ fmt.comptimePrint("{d};", .{@intFromEnum(color)}),
                    .Bright => |color| buff.* = buff.* ++ fmt.comptimePrint("{d};", .{@intFromEnum(color)}),
                    .@"8bit" => |color_code| buff.* = buff.* ++ fmt.comptimePrint("38;5;{d};", .{color_code}),
                    .@"24bit" => |color| buff.* = buff.* ++ fmt.comptimePrint("38;2;{d};{d};{d};", .{ color.r, color.g, color.b }),
                },
                // There is probably a way to avoid this duplication
                .Background => |background| switch (background) {
                    .Normal => |color| buff.* = buff.* ++ fmt.comptimePrint("{d};", .{@intFromEnum(color)}),
                    .Bright => |color| buff.* = buff.* ++ fmt.comptimePrint("{d};", .{@intFromEnum(color)}),
                    .@"8bit" => |color_code| buff.* = buff.* ++ fmt.comptimePrint("48;5;{d};", .{color_code}),
                    .@"24bit" => |color| buff.* = buff.* ++ fmt.comptimePrint("48;2;{d};{d};{d};", .{ color.r, color.g, color.b }),
                },
                .Underline => |underline| switch (underline) {
                    .@"8bit" => |color_code| buff.* = buff.* ++ fmt.comptimePrint("58;5;{d};", .{color_code}),
                    .@"24bit" => |color| buff.* = buff.* ++ fmt.comptimePrint("58;2;{d};{d};{d};", .{ color.r, color.g, color.b }),
                },
            },
        }
    }
}

pub const Parser = struct {
    /// Currently supported tokens:
    /// - Normal Attributes:
    ///     - `r` - Smart Reset
    ///     - `b` - Bold
    ///     - `d` - Dim
    ///     - `i` - Italic
    ///     - `u` - Underline
    ///     - `du` - Double Underline
    /// - Colors:
    ///     - `f:<color>` - 3bit & 4bit Foreground Coloring (prefix with `b` for bright colors) ex: `f:bRed`, `f:blue`
    ///     - `f:n` - 8bit (0 - 255) Foreground Coloring
    ///     - `f:r,g,b` - 24bit (rgb) Foreground Coloring
    ///     - `b:<color>` - 3bit & 4bit Background Coloring (prefix with `b` for bright colors) ex: `f:bRed`, `f:blue`
    ///     - `b:n` - 8bit (0 - 255) Background Coloring
    ///     - `b:r,g,b` - 24bit (rgb) Background Coloring
    ///     - `u:n` - 8bit (0 - 255) Underline Coloring
    ///     - `u:r,g,b` - 24bit (rgb) Underline Coloring
    pub fn parse(comptime text: []const u8) []const u8 {
        comptime var final_text: []const u8 = &.{};
        comptime var i: usize = 0;
        comptime var previous_is_token: bool = false;

        comptime var open: []const SGRAttribute = &.{};
        comptime var close: []const SGRAttribute = &.{};

        // Maybe we should look into using the tokenizer in the std?
        inline while (i < text.len) : (i += 1) {
            const char = text[i];
            if (char == '<') {
                i += 1;
                const start = i;

                inline while (true) {
                    if (text[i] == '>') break;
                    i = i + 1;
                    if (i > text.len) @compileError("Wrongly formatted text.");
                }

                const token = text[start..i];
                switch (token.len) {
                    0 => @compileError("Invalid Token."),
                    // Duplication galore
                    1 => switch (token[0]) {
                        'r' => {
                            if (open.len == 0) @compileError(fmt.comptimePrint("Extra reset tag found at index '{d}'", .{start + 1}));
                            const close_tag = close[close.len - 1];
                            open = open[0 .. open.len - 1];
                            close = close[0 .. close.len - 1];
                            final_text = if (previous_is_token)
                                final_text[0 .. final_text.len - 1] ++ fmt.comptimePrint(";{d}m", .{@intFromEnum(close_tag)})
                            else
                                final_text ++ fmt.comptimePrint("\x1B[{d}m", .{@intFromEnum(close_tag)});
                        },
                        'b' => {
                            open = open ++ @as([]const SGRAttribute, &.{SGRAttribute.Bold});
                            close = close ++ @as([]const SGRAttribute, &.{SGRAttribute.Not_Bold_Or_Dim});
                            final_text = if (previous_is_token)
                                final_text[0 .. final_text.len - 1] ++ fmt.comptimePrint(";{d}m", .{@intFromEnum(SGRAttribute.Bold)})
                            else
                                final_text ++ fmt.comptimePrint("\x1B[{d}m", .{@intFromEnum(SGRAttribute.Bold)});
                        },
                        'd' => {
                            open = open ++ @as([]const SGRAttribute, &.{SGRAttribute.Dim});
                            close = close ++ @as([]const SGRAttribute, &.{SGRAttribute.Not_Bold_Or_Dim});
                            final_text = if (previous_is_token)
                                final_text[0 .. final_text.len - 1] ++ fmt.comptimePrint(";{d}m", .{@intFromEnum(SGRAttribute.Dim)})
                            else
                                final_text ++ fmt.comptimePrint("\x1B[{d}m", .{@intFromEnum(SGRAttribute.Dim)});
                        },
                        'i' => {
                            open = open ++ @as([]const SGRAttribute, &.{SGRAttribute.Italic});
                            close = close ++ @as([]const SGRAttribute, &.{SGRAttribute.Not_Italic});
                            final_text = if (previous_is_token)
                                final_text[0 .. final_text.len - 1] ++ fmt.comptimePrint(";{d}m", .{@intFromEnum(SGRAttribute.Italic)})
                            else
                                final_text ++ fmt.comptimePrint("\x1B[{d}m", .{@intFromEnum(SGRAttribute.Italic)});
                        },
                        'u' => {
                            open = open ++ @as([]const SGRAttribute, &.{SGRAttribute.Underline});
                            close = close ++ @as([]const SGRAttribute, &.{SGRAttribute.Not_Underlined});
                            final_text = if (previous_is_token)
                                final_text[0 .. final_text.len - 1] ++ fmt.comptimePrint(";{d}m", .{@intFromEnum(SGRAttribute.Underline)})
                            else
                                final_text ++ fmt.comptimePrint("\x1B[{d}m", .{@intFromEnum(SGRAttribute.Underline)});
                        },
                        else => @compileError(fmt.comptimePrint("Invalid Token: '{s}'.", .{token})),
                    },
                    // Deduplication can and will be done eventually™️
                    else => {
                        if (comptime mem.eql(u8, token, "du")) {
                            open = open ++ @as([]const SGRAttribute, &.{SGRAttribute.Double_Underline});
                            close = close ++ @as([]const SGRAttribute, &.{SGRAttribute.Not_Underlined});
                            final_text = if (previous_is_token)
                                final_text[0 .. final_text.len - 1] ++ fmt.comptimePrint(";{d}m", .{@intFromEnum(SGRAttribute.Double_Underline)})
                            else
                                final_text ++ fmt.comptimePrint("\x1B[{d}m", .{@intFromEnum(SGRAttribute.Double_Underline)});
                        } else if (token[0] == 'f') {
                            // Skip `f` and `:`
                            const color_part = token[2..];
                            if (color_part.len < 1) @compileError("No valid color was passed.");
                            if (color_part[0] == '#') @compileError("Hex color codes are not yet supported.");

                            const possibly_a_int = comptime fmt.parseInt(u8, &.{color_part[0]}, 10);
                            if (possibly_a_int == error.InvalidCharacter) {
                                comptime var open_attr: SGRAttribute = undefined;
                                comptime var close_attr: SGRAttribute = undefined;
                                if (comptime mem.eql(u8, color_part, "black")) {
                                    open_attr = .Foreground_Black;
                                    close_attr = .Default_Foreground_Color;
                                } else if (comptime mem.eql(u8, color_part, "red")) {
                                    open_attr = .Foreground_Red;
                                    close_attr = .Default_Foreground_Color;
                                } else if (comptime mem.eql(u8, color_part, "green")) {
                                    open_attr = .Foreground_Green;
                                    close_attr = .Default_Foreground_Color;
                                } else if (comptime mem.eql(u8, color_part, "yellow")) {
                                    open_attr = .Foreground_Yellow;
                                    close_attr = .Default_Foreground_Color;
                                } else if (comptime mem.eql(u8, color_part, "blue")) {
                                    open_attr = .Foreground_Blue;
                                    close_attr = .Default_Foreground_Color;
                                } else if (comptime mem.eql(u8, color_part, "magenta")) {
                                    open_attr = .Foreground_Magenta;
                                    close_attr = .Default_Foreground_Color;
                                } else if (comptime mem.eql(u8, color_part, "cyan")) {
                                    open_attr = .Foreground_Cyan;
                                    close_attr = .Default_Foreground_Color;
                                } else if (comptime mem.eql(u8, color_part, "white")) {
                                    open_attr = .Foreground_White;
                                    close_attr = .Default_Foreground_Color;
                                } else if (comptime mem.eql(u8, color_part, "bBlack") || mem.eql(u8, color_part, "gray") || mem.eql(u8, color_part, "grey")) {
                                    open_attr = .Foreground_Bright_Black;
                                    close_attr = .Default_Foreground_Color;
                                } else if (comptime mem.eql(u8, color_part, "bRed")) {
                                    open_attr = .Foreground_Bright_Red;
                                    close_attr = .Default_Foreground_Color;
                                } else if (comptime mem.eql(u8, color_part, "bGreen")) {
                                    open_attr = .Foreground_Bright_Green;
                                    close_attr = .Default_Foreground_Color;
                                } else if (comptime mem.eql(u8, color_part, "bYellow")) {
                                    open_attr = .Foreground_Bright_Yellow;
                                    close_attr = .Default_Foreground_Color;
                                } else if (comptime mem.eql(u8, color_part, "bBlue")) {
                                    open_attr = .Foreground_Bright_Blue;
                                    close_attr = .Default_Foreground_Color;
                                } else if (comptime mem.eql(u8, color_part, "bMagenta")) {
                                    open_attr = .Foreground_Bright_Magenta;
                                    close_attr = .Default_Foreground_Color;
                                } else if (comptime mem.eql(u8, color_part, "bCyan")) {
                                    open_attr = .Foreground_Bright_Cyan;
                                    close_attr = .Default_Foreground_Color;
                                } else if (comptime mem.eql(u8, color_part, "bWhite")) {
                                    open_attr = .Foreground_Bright_White;
                                    close_attr = .Default_Foreground_Color;
                                }

                                open = open ++ @as([]const SGRAttribute, &.{open_attr});
                                close = close ++ @as([]const SGRAttribute, &.{close_attr});
                                final_text = if (previous_is_token)
                                    final_text[0 .. final_text.len - 1] ++ fmt.comptimePrint(";{d}m", .{@intFromEnum(open_attr)})
                                else
                                    final_text ++ fmt.comptimePrint("\x1B[{d}m", .{@intFromEnum(open_attr)});

                                continue;
                            }
                            // Handle 8bit colors
                            if (color_part.len <= 3) {
                                const color = comptime fmt.parseInt(u8, color_part, 10) catch @compileError("Failed to parse color");
                                open = open ++ @as([]const SGRAttribute, &.{SGRAttribute.Set_Foreground_Color});
                                close = close ++ @as([]const SGRAttribute, &.{SGRAttribute.Default_Foreground_Color});
                                final_text = if (previous_is_token)
                                    final_text[0 .. final_text.len - 1] ++ fmt.comptimePrint(";{d};5;{d}m", .{ @intFromEnum(SGRAttribute.Set_Foreground_Color), color })
                                else
                                    final_text ++ fmt.comptimePrint("\x1B[{d};5;{d}m", .{ @intFromEnum(SGRAttribute.Set_Foreground_Color), color });
                                continue;
                            }

                            // Handle 24 bit colors
                            // 11 is the max length of `rrr,ggg,bbb`
                            if (color_part.len > 12) @compileError(fmt.comptimePrint("Invalid color: '{s}'", .{color_part}));

                            comptime var rgb: []const u8 = &.{};
                            comptime var iterator = mem.split(u8, color_part, ",");
                            inline while (comptime iterator.next()) |color_channel| {
                                const channel_code = comptime fmt.parseInt(u8, color_channel, 10) catch @compileError("Failed to parse color");
                                rgb = rgb ++ @as([]const u8, &.{channel_code});
                            }

                            open = open ++ @as([]const SGRAttribute, &.{SGRAttribute.Set_Foreground_Color});
                            close = close ++ @as([]const SGRAttribute, &.{SGRAttribute.Default_Foreground_Color});
                            final_text = if (previous_is_token)
                                final_text[0 .. final_text.len - 1] ++ fmt.comptimePrint(";{d};2;{d};{d};{d}m", .{ @intFromEnum(SGRAttribute.Set_Foreground_Color), rgb[0], rgb[1], rgb[2] })
                            else
                                final_text ++ fmt.comptimePrint("\x1B[{d};2;{d};{d};{d}m", .{ @intFromEnum(SGRAttribute.Set_Foreground_Color), rgb[0], rgb[1], rgb[2] });
                        } else if (token[0] == 'b') {
                            // Skip `b` and `:`
                            const color_part = token[2..];
                            if (color_part.len < 1) @compileError("No valid color was passed.");
                            if (color_part[0] == '#') @compileError("Hex color codes are not yet supported.");

                            const possibly_a_int = comptime fmt.parseInt(u8, &.{color_part[0]}, 10);
                            if (possibly_a_int == error.InvalidCharacter) {
                                comptime var open_attr: SGRAttribute = undefined;
                                comptime var close_attr: SGRAttribute = undefined;
                                if (comptime mem.eql(u8, color_part, "black")) {
                                    open_attr = .Background_Black;
                                    close_attr = .Default_Background_Color;
                                } else if (comptime mem.eql(u8, color_part, "red")) {
                                    open_attr = .Background_Red;
                                    close_attr = .Default_Background_Color;
                                } else if (comptime mem.eql(u8, color_part, "green")) {
                                    open_attr = .Background_Green;
                                    close_attr = .Default_Background_Color;
                                } else if (comptime mem.eql(u8, color_part, "yellow")) {
                                    open_attr = .Background_Yellow;
                                    close_attr = .Default_Background_Color;
                                } else if (comptime mem.eql(u8, color_part, "blue")) {
                                    open_attr = .Background_Blue;
                                    close_attr = .Default_Background_Color;
                                } else if (comptime mem.eql(u8, color_part, "magenta")) {
                                    open_attr = .Background_Magenta;
                                    close_attr = .Default_Background_Color;
                                } else if (comptime mem.eql(u8, color_part, "cyan")) {
                                    open_attr = .Background_Cyan;
                                    close_attr = .Default_Background_Color;
                                } else if (comptime mem.eql(u8, color_part, "white")) {
                                    open_attr = .Background_White;
                                    close_attr = .Default_Background_Color;
                                } else if (comptime mem.eql(u8, color_part, "bBlack") || mem.eql(u8, color_part, "gray") || mem.eql(u8, color_part, "grey")) {
                                    open_attr = .Background_Bright_Black;
                                    close_attr = .Default_Background_Color;
                                } else if (comptime mem.eql(u8, color_part, "bRed")) {
                                    open_attr = .Background_Bright_Red;
                                    close_attr = .Default_Background_Color;
                                } else if (comptime mem.eql(u8, color_part, "bGreen")) {
                                    open_attr = .Background_Bright_Green;
                                    close_attr = .Default_Background_Color;
                                } else if (comptime mem.eql(u8, color_part, "bYellow")) {
                                    open_attr = .Background_Bright_Yellow;
                                    close_attr = .Default_Background_Color;
                                } else if (comptime mem.eql(u8, color_part, "bBlue")) {
                                    open_attr = .Background_Bright_Blue;
                                    close_attr = .Default_Background_Color;
                                } else if (comptime mem.eql(u8, color_part, "bMagenta")) {
                                    open_attr = .Background_Bright_Magenta;
                                    close_attr = .Default_Background_Color;
                                } else if (comptime mem.eql(u8, color_part, "bCyan")) {
                                    open_attr = .Background_Bright_Cyan;
                                    close_attr = .Default_Background_Color;
                                } else if (comptime mem.eql(u8, color_part, "bWhite")) {
                                    open_attr = .Background_Bright_White;
                                    close_attr = .Default_Background_Color;
                                }

                                open = open ++ @as([]const SGRAttribute, &.{open_attr});
                                close = close ++ @as([]const SGRAttribute, &.{close_attr});
                                final_text = if (previous_is_token)
                                    final_text[0 .. final_text.len - 1] ++ fmt.comptimePrint(";{d}m", .{@intFromEnum(open_attr)})
                                else
                                    final_text ++ fmt.comptimePrint("\x1B[{d}m", .{@intFromEnum(open_attr)});

                                continue;
                            }
                            // Handle 8bit colors
                            if (color_part.len <= 3) {
                                const color = comptime fmt.parseInt(u8, color_part, 10) catch @compileError("Failed to parse color");
                                open = open ++ @as([]const SGRAttribute, &.{SGRAttribute.Set_Background_Color});
                                close = close ++ @as([]const SGRAttribute, &.{SGRAttribute.Default_Background_Color});
                                final_text = if (previous_is_token)
                                    final_text[0 .. final_text.len - 1] ++ fmt.comptimePrint(";{d};5;{d}m", .{ @intFromEnum(SGRAttribute.Set_Background_Color), color })
                                else
                                    final_text ++ fmt.comptimePrint("\x1B[{d};5;{d}m", .{ @intFromEnum(SGRAttribute.Set_Background_Color), color });
                                continue;
                            }

                            // Handle 24 bit colors
                            // 11 is the max length of `rrr,ggg,bbb`
                            if (color_part.len > 12) @compileError(fmt.comptimePrint("Invalid color: '{s}'", .{color_part}));

                            comptime var rgb: []const u8 = &.{};
                            comptime var iterator = mem.split(u8, color_part, ",");
                            inline while (comptime iterator.next()) |color_channel| {
                                const channel_code = comptime fmt.parseInt(u8, color_channel, 10) catch @compileError("Failed to parse color");
                                rgb = rgb ++ @as([]const u8, &.{channel_code});
                            }

                            open = open ++ @as([]const SGRAttribute, &.{SGRAttribute.Set_Background_Color});
                            close = close ++ @as([]const SGRAttribute, &.{SGRAttribute.Default_Background_Color});
                            final_text = if (previous_is_token)
                                final_text[0 .. final_text.len - 1] ++ fmt.comptimePrint(";{d};2;{d};{d};{d}m", .{ @intFromEnum(SGRAttribute.Set_Background_Color), rgb[0], rgb[1], rgb[2] })
                            else
                                final_text ++ fmt.comptimePrint("\x1B[{d};2;{d};{d};{d}m", .{ @intFromEnum(SGRAttribute.Set_Background_Color), rgb[0], rgb[1], rgb[2] });
                        } else if (token[0] == 'u') {
                            // Skip `u` and `:`
                            const color_part = token[2..];
                            if (color_part.len < 1) @compileError("No valid color was passed.");
                            if (color_part[0] == '#') @compileError("Hex color codes are not yet supported.");

                            // Handle 8bit colors
                            if (color_part.len <= 3) {
                                const color = comptime fmt.parseInt(u8, color_part, 10) catch @compileError("Failed to parse color");
                                open = open ++ @as([]const SGRAttribute, &.{SGRAttribute.Set_Background_Color});
                                close = close ++ @as([]const SGRAttribute, &.{SGRAttribute.Default_Background_Color});
                                final_text = if (previous_is_token)
                                    final_text[0 .. final_text.len - 1] ++ fmt.comptimePrint(";{d};5;{d}m", .{ @intFromEnum(SGRAttribute.Set_Background_Color), color })
                                else
                                    final_text ++ fmt.comptimePrint("\x1B[{d};5;{d}m", .{ @intFromEnum(SGRAttribute.Set_Background_Color), color });
                                continue;
                            }

                            // Handle 24bit colors
                            // 11 is the max length of `rrr,ggg,bbb`
                            if (color_part.len > 12) @compileError(fmt.comptimePrint("Invalid color: '{s}'", .{color_part}));

                            comptime var rgb: []const u8 = &.{};
                            comptime var iterator = mem.split(u8, color_part, ",");
                            inline while (comptime iterator.next()) |color_channel| {
                                const channel_code = comptime fmt.parseInt(u8, color_channel, 10) catch @compileError("Failed to parse color");
                                rgb = rgb ++ @as([]const u8, &.{channel_code});
                            }

                            open = open ++ @as([]const SGRAttribute, &.{SGRAttribute.Set_Underline_Color});
                            close = close ++ @as([]const SGRAttribute, &.{SGRAttribute.Default_Underline_Color});
                            final_text = if (previous_is_token)
                                final_text[0 .. final_text.len - 1] ++ fmt.comptimePrint(";{d};2;{d};{d};{d}m", .{ @intFromEnum(SGRAttribute.Set_Underline_Color), rgb[0], rgb[1], rgb[2] })
                            else
                                final_text ++ fmt.comptimePrint("\x1B[{d};2;{d};{d};{d}m", .{ @intFromEnum(SGRAttribute.Set_Underline_Color), rgb[0], rgb[1], rgb[2] });
                        } else {
                            @compileError(fmt.comptimePrint("Invalid Token: '{s}'.", .{token}));
                        }
                    },
                }
                previous_is_token = true;
                continue;
            }

            final_text = final_text ++ @as([]const u8, &.{char});
            previous_is_token = false;
        }

        if (open.len > 0) @compileError("Text has an unclosed token.");

        return final_text;
    }
};
