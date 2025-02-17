const FeEscapeSequence = @import("./ansi.zig").FeEscapeSequence;
const Color = @import("./Color.zig");
const std = @import("std");
const fmt = std.fmt;
const mem = std.mem;

/// Not all SGR Attributes are supported by all terminals,
/// it's up for the developer to know which ones work and which don't.
pub const Attribute = enum(u8) {
    reset,
    bold,
    dim,
    italic,
    underline,
    slow_blink,
    rapid_blink,
    // Invert foreground and background colors
    invert,
    hide,
    strike_through,
    default_font,
    font_1,
    font_2,
    font_3,
    font_4,
    font_5,
    font_6,
    font_7,
    font_8,
    font_9,
    font_gothic,
    /// In some terminals this acts as code 22 (not bold).
    double_underline,
    not_bold_or_dim,
    not_italic,
    not_underlined,
    not_blinking,
    proportional_spacing,
    not_inverted,
    reveal,
    not_crossed_out,
    foreground_black,
    foreground_red,
    foreground_green,
    foreground_yellow,
    foreground_blue,
    foreground_magenta,
    foreground_cyan,
    foreground_white,
    /// Used for 8bit and 24bit (true color).
    set_foreground_color,
    default_foreground_color,
    background_black,
    background_red,
    background_green,
    background_yellow,
    background_blue,
    background_magenta,
    background_cyan,
    background_white,
    /// Used for 8bit and 24bit (true color).
    set_background_color,
    default_background_color,
    disable_proportional_spacing,
    framed,
    encircled,
    overlined,
    not_framed_or_encircled,
    not_overlined,
    /// Follows the same convention as codes 38 and 48.
    /// Only supports 8bit and 24bit colors.
    set_underline_color = 58,
    default_underline_color,
    ideogram_underline_or_right_side_line,
    ideogram_double_underline_or_double_line_on_right_side,
    ideogram_overline_or_left_side_line,
    ideogram_double_overline_or_double_line_on_left_side,
    ideogram_stress_marking,
    /// Disables all codes 60 to 64
    no_ideogram_attributes,
    superscript = 73,
    subscript,
    not_superscript_or_subscript,
    foreground_bright_black = 90,
    foreground_bright_red,
    foreground_bright_green,
    foreground_bright_yellow,
    foreground_bright_blue,
    foreground_bright_magenta,
    foreground_bright_cyan,
    foreground_bright_white,
    background_bright_black = 100,
    background_bright_red,
    background_bright_green,
    background_bright_yellow,
    background_bright_blue,
    background_bright_magenta,
    background_bright_cyan,
    background_bright_white,

    // TODO: Support currently invalid attributes
    // Invalid attributes wont work, they are the following:
    // set_foreground_color, set_background_color, set_underline_color
    pub fn str(comptime self: Attribute) []const u8 {
        return std.fmt.comptimePrint(FeEscapeSequence.CSI ++ "{d}m", .{@intFromEnum(self)});
    }
};

pub const Modifier = union(enum) {
    color: union(enum) { foreground: union(enum) {
        @"8bit": u8,
        @"24bit": struct {
            r: u8,
            g: u8,
            b: u8,
        },
        normal: enum(u8) { black = 30, red, green, yellow, blue, magenta, cyan, white },
        bright: enum(u8) { black = 90, red, green, yellow, blue, magenta, cyan, white },
    }, background: union(enum) {
        @"8bit": u8,
        @"24bit": struct {
            r: u8,
            g: u8,
            b: u8,
        },
        normal: enum(u8) { black = 40, red, green, yellow, blue, magenta, cyan, white },
        bright: enum(u8) { black = 100, red, green, yellow, blue, magenta, cyan, white },
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
        0 => @intFromEnum(Attribute.default_foreground_color),
        10 => @intFromEnum(Attribute.default_background_color),
        else => @compileError("Only 0 and 10 are supported additives."),
    };

    return struct {
        const black: SGRCode = .{ .open = @intFromEnum(Attribute.foreground_black) + additive, .close = close };
        const red: SGRCode = .{ .open = @intFromEnum(Attribute.foreground_red) + additive, .close = close };
        const green: SGRCode = .{ .open = @intFromEnum(Attribute.foreground_green) + additive, .close = close };
        const yellow: SGRCode = .{ .open = @intFromEnum(Attribute.foreground_yellow) + additive, .close = close };
        const blue: SGRCode = .{ .open = @intFromEnum(Attribute.foreground_blue) + additive, .close = close };
        const magenta: SGRCode = .{ .open = @intFromEnum(Attribute.foreground_magenta) + additive, .close = close };
        const cyan: SGRCode = .{ .open = @intFromEnum(Attribute.foreground_cyan) + additive, .close = close };
        const white: SGRCode = .{ .open = @intFromEnum(Attribute.foreground_white) + additive, .close = close };
        const bBlack: SGRCode = .{ .open = @intFromEnum(Attribute.foreground_bright_black) + additive, .close = close };
        const bRed: SGRCode = .{ .open = @intFromEnum(Attribute.foreground_bright_red) + additive, .close = close };
        const bGreen: SGRCode = .{ .open = @intFromEnum(Attribute.foreground_bright_green) + additive, .close = close };
        const bYellow: SGRCode = .{ .open = @intFromEnum(Attribute.foreground_bright_yellow) + additive, .close = close };
        const bBlue: SGRCode = .{ .open = @intFromEnum(Attribute.foreground_bright_blue) + additive, .close = close };
        const bMagenta: SGRCode = .{ .open = @intFromEnum(Attribute.foreground_bright_magenta) + additive, .close = close };
        const bCyan: SGRCode = .{ .open = @intFromEnum(Attribute.foreground_bright_cyan) + additive, .close = close };
        const bWhite: SGRCode = .{ .open = @intFromEnum(Attribute.foreground_bright_white) + additive, .close = close };
        const gray = bBlack;
        const grey = bBlack;
    };
}

const ForegroundColors = CreateAvailableColors(0);
const BackgroundColors = CreateAvailableColors(10);

const default_tags = struct {
    const b = .{ Attribute.bold, Attribute.not_bold_or_dim };
    const d = .{ Attribute.dim, Attribute.not_bold_or_dim };
    const i = .{ Attribute.italic, Attribute.not_italic };
    const u = .{ Attribute.underline, Attribute.not_underlined };
    const s = .{ Attribute.strike_through, Attribute.not_crossed_out };
    const o = .{ Attribute.overlined, Attribute.not_overlined };
    const du = .{ Attribute.double_underline, Attribute.not_underlined };
    const inv = .{ Attribute.invert, Attribute.not_inverted };
};

/// Custom tags cannot have `:` as their second byte
/// it will cause them to not be detected
pub fn Parser(comptime custom_tags: anytype) type {
    if (@TypeOf(custom_tags) != void) {
        switch (@typeInfo(custom_tags)) {
            // TODO: improve validation of struct
            .Struct => {},
            .Void => {},
            else => @compileError(std.fmt.comptimePrint("Invalid type: expected 'struct' or 'void' got: {any}", .{@typeInfo((custom_tags))})),
        }
    }

    return struct {
        /// Special Tags:
        /// - `r` - Smart Reset
        ///
        /// Default Tags:
        /// - `b` - Bold
        /// - `d` - Dim
        /// - `i` - Italic
        /// - `u` - Underline
        /// - `s` - Strike through (crossed)
        /// - `o` - Overlined
        /// - `du` - Double Underline
        /// - `inv` - Invert
        ///
        /// Coloring:
        /// - `f:<color>` - 3bit & 4bit Foreground Coloring (prefix with `b` for bright colors) ex: `f:bRed`, `f:blue`
        /// - `f:n` - 8bit (0 - 255) Foreground Coloring
        /// - `f:r,g,b` - 24bit (rgb) Foreground Coloring
        /// - `f:#ffffff` - Hex code (24bit)
        /// - `f:<color_space>:x,y,z` - 24bit color using specific color space
        /// - `b:<color>` - 3bit & 4bit Background Coloring (prefix with `b` for bright colors)
        /// - `b:n` - 8bit (0 - 255) Background Coloring
        /// - `b:r,g,b` - 24bit (rgb) Background Coloring
        /// - `b:#ffffff` - Hex code (24bit)
        /// - `b:<color_space>:x,y,z` - 24bit color using specific color space
        /// - `u:n` - 8bit (0 - 255) Underline Coloring
        /// - `u:r,g,b` - 24bit (rgb) Underline Coloring
        /// - `u:#ffffff` - Hex code (24bit)
        /// - `u:<color_space>:x,y,z` - 24bit color using specific color space
        ///
        /// Available color spaces are: `hsv`, `hsl` and `hsi`
        pub inline fn parseString(comptime text: []const u8) []const u8 {
            comptime {
                var final_text: []const u8 = &.{};
                var stack: []const Attribute = &.{};
                var i: usize = 0;
                var previous_is_tag: bool = false;

                while (i < text.len) : (i += 1) {
                    const char = text[i];
                    if (char != '<') {
                        final_text = final_text ++ @as([]const u8, &.{char});
                        previous_is_tag = false;
                        continue;
                    }

                    // If the user escaped the character then we don't read it as a token
                    if (i != 0 and text[i - 1] == '\\') {
                        final_text = final_text[0 .. final_text.len - 1] ++ @as([]const u8, &.{char});
                        previous_is_tag = false;
                        continue;
                    }

                    i += 1;
                    const start = i;

                    while (true) {
                        if (text[i] == '>') break;
                        i = i + 1;
                        if (i > text.len) @compileError("Wrongly formatted text.");
                    }

                    const tag = text[start..i];
                    if (tag.len == 0) {
                        @compileError("Invalid Empty Tag");
                    } else if (tag.len == 1 and tag[0] == 'r') {
                        if (stack.len == 0) @compileError(fmt.comptimePrint("Extra reset tag found at index '{d}'", .{start + 1}));
                        appendAttribute(&final_text, stack[stack.len - 1], previous_is_tag);
                        stack = stack[0 .. stack.len - 1];
                    } else if (tag.len > 1 and tag[1] == ':') {
                        if (tag[0] == 'f') {
                            parseColorAttribute(&final_text, &stack, tag, .{ .set_foreground_color, .default_foreground_color }, previous_is_tag);
                        } else if (tag[0] == 'b') {
                            parseColorAttribute(&final_text, &stack, tag, .{ .set_background_color, .default_background_color }, previous_is_tag);
                        } else if (tag[0] == 'u') {
                            parseColorAttribute(&final_text, &stack, tag, .{ .set_underline_color, .default_underline_color }, previous_is_tag);
                        } else {
                            @compileError(fmt.comptimePrint("Invalid Tag: '{s}'.", .{tag}));
                        }
                    } else {
                        const field = if (@TypeOf(custom_tags) != void and @hasDecl(custom_tags, tag))
                            @field(custom_tags, tag)
                        else if (@hasDecl(default_tags, tag))
                            @field(default_tags, tag)
                        else
                            @compileError(fmt.comptimePrint("Invalid Tag: '{s}'.", .{tag}));

                        appendAttribute(&final_text, field[0], previous_is_tag);
                        stack = stack ++ @as([]const Attribute, &.{field[1]});
                    }

                    previous_is_tag = true;
                }

                if (stack.len > 0) @compileError("Text has an unclosed tag.");
                return final_text;
            }
        }

        fn appendAttribute(
            buf: *[]const u8,
            opening: Attribute,
            trim_last_byte: bool,
        ) void {
            comptime {
                buf.* = if (trim_last_byte)
                    buf.*[0 .. buf.*.len - 1] ++ fmt.comptimePrint(";{d}m", .{@intFromEnum(opening)})
                else
                    buf.* ++ fmt.comptimePrint(FeEscapeSequence.CSI ++ "{d}m", .{@intFromEnum(opening)});
            }
        }

        fn parseColorAttribute(
            buf: *[]const u8,
            stack: *[]const Attribute,
            tag: []const u8,
            attributes: struct { Attribute, Attribute },
            trim_last_byte: bool,
        ) void {
            const color_part = tag[2..];
            if (color_part.len < 1) @compileError("No valid color was passed.");

            const opening, const closing = attributes;
            const possibly_a_int = fmt.parseInt(u8, &.{color_part[0]}, 10);

            if (possibly_a_int == error.InvalidCharacter) {
                // Handle hex as 24bit
                if (color_part[0] == '#') {
                    const color = Color.fromHex(color_part) catch @compileError(fmt.comptimePrint("Invalid hex color: '{s}'", .{color_part}));
                    append24BitColor(buf, color, opening, trim_last_byte);
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

                    append24BitColor(buf, color, opening, trim_last_byte);
                    // Handle 4bit
                } else {
                    const color = switch (opening) {
                        .set_foreground_color => @field(ForegroundColors, color_part),
                        .set_background_color => @field(BackgroundColors, color_part),
                        .set_underline_color => @compileError("Underline doesn't support 4bit colors."),
                        else => @compileError("Invalid Attribute"),
                    };

                    appendAttribute(buf, @enumFromInt(color.open), trim_last_byte);
                }
                // Handle 8bit colors
            } else if (color_part.len <= 3) {
                append8BitColor(buf, color_part, opening, trim_last_byte);
                // Handle 24 bit colors
            } else {
                append24BitColor(buf, parseStringRGB(color_part), opening, trim_last_byte);
            }

            stack.* = stack.* ++ @as([]const Attribute, &.{closing});
        }

        fn append24BitColor(
            buf: *[]const u8,
            color: Color,
            open_code: Attribute,
            trim_last_byte: bool,
        ) void {
            comptime {
                buf.* = if (trim_last_byte)
                    buf.*[0 .. buf.*.len - 1] ++ fmt.comptimePrint(";{d};2;{d};{d};{d}m", .{ @intFromEnum(open_code), color.red8Bit(), color.green8Bit(), color.blue8Bit() })
                else
                    buf.* ++ fmt.comptimePrint(FeEscapeSequence.CSI ++ "{d};2;{d};{d};{d}m", .{ @intFromEnum(open_code), color.red8Bit(), color.green8Bit(), color.blue8Bit() });
            }
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
    };
}

pub const parseString = Parser({}).parseString;
