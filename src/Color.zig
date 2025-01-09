//! This is a direct port of the original Color class from tasai
//! https://github.com/Didas-git/tasai/blob/main/src/structures/color.ts
const std = @import("std");
const Math = @import("./math.zig").Math;

const math = Math(f64);

const Color = @This();

r: f64,
g: f64,
b: f64,
a: f64,

pub fn init(r: f64, g: f64, b: f64, alpha: ?f64) Color {
    return .{
        .r = @min(@max(r, 0), 1),
        .g = @min(@max(g, 0), 1),
        .b = @min(@max(b, 0), 1),
        .a = @min(@max(alpha orelse 1, 0), 1),
    };
}

pub fn red8Bit(self: *const Color) u8 {
    return @round(self.r * 0xFF);
}
pub fn green8Bit(self: *const Color) u8 {
    return @round(self.g * 0xFF);
}
pub fn blue8Bit(self: *const Color) u8 {
    return @round(self.b * 0xFF);
}
pub fn alpha8Bit(self: *const Color) u8 {
    return @round(self.a * 0xFF);
}

pub fn toRGB(self: *Color) [3]f64 {
    return .{
        self.r,
        self.g,
        self.b,
    };
}

pub fn toRGBA(self: *Color) [4]f64 {
    return .{
        self.r,
        self.g,
        self.b,
        self.a,
    };
}

pub fn to24BitRGB(self: *Color) [3]u8 {
    return .{
        self.red8Bit(),
        self.green8Bit(),
        self.blue8Bit(),
    };
}

pub fn to32BitRGBA(self: *Color) [4]u8 {
    return .{
        self.red8Bit(),
        self.green8Bit(),
        self.blue8Bit(),
        self.alpha8Bit(),
    };
}

pub fn toHSV(self: *Color) [3]u8 {
    return .{ self.hue(), self.saturationHSV(), self.value() };
}

pub fn toHSL(self: *Color) [3]u8 {
    return .{ self.hue(), self.saturationHSL(), self.lightness() };
}

pub fn toHSI(self: *Color) [3]u8 {
    return .{ self.hue(), self.saturationHSI(), self.intensity() };
}

pub fn chroma(self: *Color) f64 {
    return @max(self.r, self.g, self.b) - @min(self.r, self.g, self.b);
}

pub fn hue(self: *Color) f64 {
    if (self.chroma() == 0) return 0;

    const huePrime: f64 = switch (@max(self.r, self.g, self.b)) {
        self.r => ((self.g - self.b) / self.chroma() + 6) % 6,
        self.g => (self.b - self.r) / self.chroma() + 2,
        self.b => (self.r - self.g) / self.chroma() + 4,
        else => 0,
    };

    return huePrime / 6;
}

pub fn intensity(self: *Color) f64 {
    return math.avg(self.toRGB());
}

pub fn value(self: *Color) f64 {
    return @max(@max(self.r, self.g), self.b);
}

pub fn lightness(self: *Color) f64 {
    return math.mid(self.toRGB());
}

pub fn saturationHSV(self: *Color) f64 {
    return if (self.value() == 0) 0 else self.chroma() / self.value();
}

pub fn saturationHSL(self: *Color) f64 {
    return if (self.lightness() % 1 == 0) 0 else self.chroma() / (1 - @abs(2 * self.lightness() - 1));
}

pub fn saturationHSI(self: *Color) f64 {
    return if (self.intensity() == 0) 0 else 1 - @min(@min(self.r, self.g), self.b) / self.intensity();
}

pub fn fromHex(hex: []const u8) !Color {
    const trimmed_hex = if (hex[0] == '#') hex[1..] else if (std.mem.eql(u8, hex[0..2], "0x")) hex[2..] else hex;
    const color = try std.fmt.parseInt(u32, trimmed_hex, 16);
    var r: f64 = 0;
    var g: f64 = 0;
    var b: f64 = 0;

    switch (trimmed_hex.len) {
        2 => {
            r = @as(f32, (color & 0b1110_0000)) / 0b1110_0000;
            g = @as(f32, (color & 0b0001_1100)) / 0b0001_1100;
            b = @as(f32, (color & 0b0000_0011)) / 0b0000_0011;
        },
        3 => {
            r = @as(f32, (color & 0xF00)) / 0xF00;
            g = @as(f32, (color & 0x0F0)) / 0x0F0;
            b = @as(f32, (color & 0x00F)) / 0x00F;
        },
        4 => {
            r = @as(f32, (color & 0xF800)) / 0xF800;
            g = @as(f32, (color & 0x07E0)) / 0x07E0;
            b = @as(f32, (color & 0x001F)) / 0x001F;
        },
        6 => {
            r = @as(f32, (color & 0xFF_00_00)) / 0xFF_00_00;
            g = @as(f32, (color & 0x00_FF_00)) / 0x00_FF_00;
            b = @as(f32, (color & 0x00_00_FF)) / 0x00_00_FF;
        },
        9 => {
            r = @as(f32, (color & 0xFFF_000_000)) / 0xFFF_000_000;
            g = @as(f32, (color & 0x000_FFF_000)) / 0x000_FFF_000;
            b = @as(f32, (color & 0x000_000_FFF)) / 0x000_000_FFF;
        },
        12 => {
            r = @as(f32, (color & 0xFFFF_0000_0000)) / 0xFFFF_0000_0000;
            g = @as(f32, (color & 0x0000_FFFF_0000)) / 0x0000_FFFF_0000;
            b = @as(f32, (color & 0x0000_0000_FFFF)) / 0x0000_0000_FFFF;
        },
        else => return error.InvalidHexLength,
    }

    return Color.init(r, g, b, null);
}

pub fn fromCXM(hueRegion: u64, chr: f64, X: f64, m: f64, alpha: f64) Color {
    return switch (hueRegion) {
        0 => return Color.init(chr + m, X + m, m, alpha),
        1 => return Color.init(X + m, chr + m, m, alpha),
        2 => return Color.init(m, chr + m, X + m, alpha),
        3 => return Color.init(m, X + m, chr + m, alpha),
        4 => return Color.init(X + m, m, chr + m, alpha),
        5 => return Color.init(chr + m, m, X + m, alpha),
        else => Color.init(0, 0, 0, null),
    };
}

pub fn fromHSV(h: f64, saturation: f64, val: f64, alpha: ?f64) Color {
    const chr = val * saturation;
    const scaledHue = h * 6;

    // integer to isolate the 6 separate cases for hue
    const hueRegion = @floor(scaledHue);

    // intermediate value for second largest component
    const X = chr * (1 - @abs(scaledHue % 2 - 1));

    // constant to add to all color components
    const m = val - chr;

    return Color.fromCXM(hueRegion, chr, X, m, alpha orelse 1);
}

pub fn fromHSL(h: f64, saturation: f64, l: f64, alpha: ?f64) Color {
    const chr = (1 - @abs(2 * l - 1)) * saturation;
    const scaledHue = h * 6;

    // integer to isolate the 6 separate cases for hue
    const hueRegion = @floor(scaledHue);

    // intermediate value for second largest component
    const X = chr * (1 - @abs(scaledHue % 2 - 1));

    // constant to add to all color components
    const m = l - chr * 0.5;

    return Color.fromCXM(hueRegion, chr, X, m, alpha orelse 1);
}

pub fn fromHSI(h: f64, saturation: f64, in: f64, alpha: ?f64) Color {
    const scaledHue = h * 6;

    // integer to isolate the 6 separate cases for hue
    const hueRegion = @floor(scaledHue);

    const Z = 1 - @abs(scaledHue % 2 - 1);

    const chr = 3 * in * saturation / (1 + Z);

    // intermediate value for second largest component
    const X = chr * Z;

    // constant to add to all color components
    const m = in * (1 - saturation);

    return Color.fromCXM(hueRegion, chr, X, m, alpha orelse 1);
}

pub fn from24BitRGB(r: f64, g: f64, b: f64) Color {
    return Color.from32BitRGBA(r, g, b);
}

pub fn from32BitRGBA(r: f64, g: f64, b: f64, alpha: ?f64) Color {
    return Color.init(r / 0xFF, g / 0xFF, b / 0xFF, if (alpha) |a| a / 0xFF else 1);
}

pub fn toString(self: *Color, buf: []u8) void {
    return std.fmt.bufPrint(buf, "Color(r: {d}, g: {d}, b: {d}, a: {d})", .{ self.r, self.g, self.b });
}
