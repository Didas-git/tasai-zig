const FeEscapeSequence = @import("./control_codes.zig").FeEscapeSequence;
const std = @import("std");
const fmt = std.fmt;

pub inline fn hyperlink(comptime alt_text: []const u8, comptime link: []const u8, comptime options: anytype) []const u8 {
    comptime {
        var params: []const u8 = &.{};

        const options_type = @typeInfo(@TypeOf(options));
        switch (options_type) {
            .Null => {},
            .Struct => |opt| for (opt.fields) |field| {
                params = params ++ fmt.comptimePrint("{s}={any}:", .{ field.name, @field(options, field.name) });
            },
            else => @compileError("Options should be a struct."),
        }

        return FeEscapeSequence.OSC ++ "8;" ++ (if (params.len > 0) params[0 .. params.len - 1] else "") ++ ";" ++ link ++ FeEscapeSequence.ST ++ alt_text ++ FeEscapeSequence.OSC ++ "8;;" ++ FeEscapeSequence.ST;
    }
}
