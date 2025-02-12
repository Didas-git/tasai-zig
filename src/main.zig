const std = @import("std");
const tasai = @import("./tasai.zig");
const SelectPrompt = @import("./prompts/select.zig").SelectPrompt;
const ConfirmPrompt = @import("./prompts/confirm.zig").ConfirmPrompt;

const KV = tasai.KV;
const OSC = tasai.OSC;
const CSI = tasai.CSI;

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

    std.debug.print("{s}\n", .{tasai.comptimeStrip(str)});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    std.debug.print("{s}\n", .{try tasai.strip(allocator, str)});

    const std_out = std.io.getStdOut();
    const writer = std_out.writer();

    const c_p = ConfirmPrompt(.{ .message = "Are you alive?" });
    const answer1 = try c_p.run(allocator);
    try writer.print("Answer: {any}\n", .{answer1});

    const s_p = SelectPrompt([]const u8, .{
        .message = "Pick",
        .choices = &.{
            "Almond",
            "Apple",
            "Banana",
            "Blackberry",
            "Blueberry",
            "Cherry",
            "Chocolate",
            "Cinnamon",
            "Coconut",
            "Cranberry",
            "Grape",
            "Nougat",
            "Orange",
            "Pear",
            "Pineapple",
            "Raspberry",
            "Strawberry",
            "Vanilla",
            "Watermelon",
            "Wintergreen",
        },
    });

    const answer2 = try s_p.run(allocator);
    try writer.print("Answer: {s}\n", .{answer2});

    const StringKV = KV([]const u8);

    const s_p2 = SelectPrompt(StringKV, .{
        .message = "Pick",
        .choices = &.{
            .{ .name = "Apple", .value = "I Love Apples" },
            .{ .name = "Orange", .value = "I Love Oranges" },
            .{ .name = "Grape", .value = "I Love Grapes" },
        },
    });

    const answer3 = try s_p2.run(allocator);
    try writer.print("Answer: {s}\n", .{answer3});

    const BooleanKV = KV(bool);

    const s_p3 = SelectPrompt(BooleanKV, .{
        .message = "Pick",
        .choices = &.{
            .{ .name = "Apple", .value = false },
            .{ .name = "Orange", .value = true },
            .{ .name = "Grape", .value = false },
        },
    });

    const answer4 = try s_p3.run(allocator);
    try writer.print("Answer: {any}\n", .{answer4});
}
