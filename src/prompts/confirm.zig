const std = @import("std");
const CSI = @import("../csi.zig");
const Terminal = @import("../Terminal.zig");
const Prompt = @import("../prompt.zig").Prompt(bool, void);

pub fn ConfirmPrompt(comptime options: struct {
    message: []const u8,
    default_value: bool = false,
    toggle: bool = false,
    toggle_names: [2][]const u8 = .{ "No", "Yes" },
    header: [2][]const u8 = .{ "?", "\u{1f5f8}" },
    footer: [2][]const u8 = .{ "\u{25b8}", "\u{00b7}" },
}) Prompt {
    std.debug.assert(options.message.len > 0);

    const visual_options = if (options.default_value) "(Y/n)" else "(y/N)";
    const ask = std.fmt.comptimePrint(CSI.SGR.parseString("<f:cyan><b>{s}<r><r> {s} <d>{s} {s}<r> <f:cyan>{s}<r>"), .{
        options.header[0],
        options.message,
        visual_options,
        options.footer[0],
        if (options.default_value) "true" else "false",
    });
    const done = std.fmt.comptimePrint(CSI.SGR.parseString("<f:green><b>{s}<r><r> {s} <d>{s} {s}<r> "), .{
        options.header[1],
        options.message,
        visual_options,
        options.footer[1],
    });

    const toggle_asking = std.fmt.comptimePrint(CSI.SGR.parseString("<f:cyan><b>{s}<r><r> {s} <d>{s}<r> "), .{
        options.header[1],
        options.message,
        options.footer[1],
    });

    const toggle_done = std.fmt.comptimePrint(CSI.SGR.parseString("<f:cyan><b>{s}<r><r> {s} <d>{s}<r> "), .{
        options.header[1],
        options.message,
        options.footer[1],
    });

    const toggle_no = std.fmt.comptimePrint(CSI.SGR.parseString("<f:cyan><u>{s}<r><r> / {s}"), .{ options.toggle_names[0], options.toggle_names[1] });
    const toggle_yes = std.fmt.comptimePrint(CSI.SGR.parseString("{s} / <f:cyan><u>{s}<r><r>"), .{ options.toggle_names[0], options.toggle_names[1] });

    const gen = struct {
        const Self = @This();

        var current: if (options.toggle) bool else void = if (options.toggle) false else {};

        pub fn prompt(comptime self: Self) Prompt {
            return .{
                .ptr = @ptrCast(@constCast(&self)),
                .vtable = &.{
                    .initialize = initialize,
                    .dispatch = dispatch,
                    .format = format,
                },
            };
        }

        fn initialize(ctx: *anyopaque, term: *Terminal, writer: std.fs.File.Writer) !void {
            _ = ctx;
            _ = term;

            if (comptime options.toggle) {
                try writer.writeAll(CSI.CUH ++ toggle_asking ++ toggle_no);
            } else {
                try writer.writeAll(CSI.CUH ++ ask);
            }
        }

        fn dispatch(ctx: *anyopaque, term: *Terminal, byte: u8) !?bool {
            _ = ctx;

            if (comptime options.toggle) {
                return switch (byte) {
                    std.ascii.control_code.lf, std.ascii.control_code.cr => current,
                    254 => {
                        if (!current) {
                            try term.stdout.writeAll(CSI.C_CHA(0) ++ CSI.EL0 ++ toggle_asking ++ toggle_yes);
                            current = true;
                        }
                        return null;
                    },
                    255 => {
                        if (current) {
                            try term.stdout.writeAll(CSI.C_CHA(0) ++ CSI.EL0 ++ toggle_asking ++ toggle_no);
                            current = false;
                        }
                        return null;
                    },
                    else => null,
                };
            } else {
                return switch (byte) {
                    std.ascii.control_code.lf, std.ascii.control_code.cr => options.default_value,

                    'y', 'Y' => true,
                    'n', 'N' => false,
                    else => null,
                };
            }
        }

        fn format(ctx: *anyopaque, term: *Terminal, writer: std.fs.File.Writer, answer: bool) !void {
            _ = ctx;
            _ = term;

            try writer.writeAll(CSI.C_CHA(0) ++ CSI.EL2);

            if (comptime options.toggle) {
                try writer.print(toggle_done ++ "{s}\n", .{if (current) toggle_yes else toggle_no});
            } else {
                try writer.print(CSI.SGR.parseString("{s}<f:green>{any}<r>\n"), .{ done, answer });
            }
        }
    };

    return gen.prompt(.{});
}
