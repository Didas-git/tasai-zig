const std = @import("std");
const OSC = @import("./osc.zig");
const ANSI = @import("./ansi.zig");
const CSI = @import("./csi.zig");
const ConfirmPrompt = @import("./prompts/confirm.zig").ConfirmPrompt;
pub fn main() !void {
    std.debug.print("{s}: {s}!\n", .{
        CSI.SGR.verboseFormat("Test", &.{
            .{ .attribute = .Double_Underline },
            .{ .color = .{ .underline = .{ .@"24bit" = .{ .r = 30, .g = 255, .b = 120 } } } },
        }, &.{
            .{ .attribute = .Not_Underlined },
            .{ .attribute = .Default_Underline_Color },
        }),
        CSI.SGR.verboseFormat(std.fmt.comptimePrint("{s} {s}", .{
            CSI.SGR.verboseFormat("Hello", &.{
                .{ .color = .{ .foreground = .{ .@"24bit" = .{ .r = 255, .g = 0, .b = 239 } } } },
            }, &.{
                .{ .attribute = .Default_Foreground_Color },
            }),
            CSI.SGR.verboseFormat("World", &.{
                .{ .attribute = .Bold },
                .{ .color = .{ .foreground = .{ .@"8bit" = 33 } } },
            }, &.{
                .{ .attribute = .Not_Bold_Or_Dim },
                .{ .attribute = .Default_Foreground_Color },
            }),
        }), &.{.{ .color = .{ .background = .{ .normal = .Black } } }}, &.{.{ .attribute = .Default_Background_Color }}),
    });

    const str = CSI.SGR.parseString("<du><u:30,255,120>Test<r><r>: <b:black><f:#ff00ef>Hello<r> <f:33><b>World<r><r><r>!");
    std.debug.print("{s}\n", .{str});
    std.debug.print("{s}\n", .{CSI.SGR.parseString("This: <b><f:red>\\<<r> should print without issues<r>")});

    std.debug.print("{s}\n", .{OSC.hyperlink("My link", "https://google.com/", null)});
    const Params = struct { id: u8 };
    std.debug.print("{s}\n", .{OSC.hyperlink("My link", "https://google.com/", Params{ .id = 1 })});
    std.debug.print("{s}\n", .{CSI.SGR.parseString("<b:hsi:0,0,0><f:hsv:0,255,255>Hello<r> <f:hsl:0.1,1,0.5>World<r><r>")});

    std.debug.print("{s}\n", .{ANSI.comptimeStrip(str)});

    var bf: [255]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&bf);
    std.debug.print("{s}\n", .{try ANSI.strip(fba.allocator(), str)});

    var buf: [64]u8 = undefined;
    var fba2 = std.heap.FixedBufferAllocator.init(&buf);
    const prompt = ConfirmPrompt(.{ .message = "Are you alive?" });

    const std_out = std.io.getStdOut();
    const answer = try prompt.run(fba2.allocator());
    const writer = std_out.writer();

    try writer.print("Answer: {s}\n", .{if (answer) "true" else "false"});
}
