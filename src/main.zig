const std = @import("std");
const tasai = @import("./tasai.zig");
const InputPrompt = @import("./prompts/input.zig").InputPrompt;
const SelectPrompt = @import("./prompts/select.zig").SelectPrompt;
const ConfirmPrompt = @import("./prompts/confirm.zig").ConfirmPrompt;

const KV = tasai.KV;
const OSC = tasai.OSC;
const CSI = tasai.CSI;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    std.debug.print("{s}: {s}!\n", .{
        CSI.SGR.verboseFormat("Test", &.{
            .{ .attribute = .double_underline },
            .{ .color = .{ .underline = .{ .@"24bit" = .{ .r = 30, .g = 255, .b = 120 } } } },
        }, &.{
            .{ .attribute = .not_underlined },
            .{ .attribute = .default_underline_color },
        }),
        CSI.SGR.verboseFormat(std.fmt.comptimePrint("{s} {s}", .{
            CSI.SGR.verboseFormat("Hello", &.{
                .{ .color = .{ .foreground = .{ .@"24bit" = .{ .r = 255, .g = 0, .b = 239 } } } },
            }, &.{
                .{ .attribute = .default_foreground_color },
            }),
            CSI.SGR.verboseFormat("World", &.{
                .{ .attribute = .bold },
                .{ .color = .{ .foreground = .{ .@"8bit" = 33 } } },
            }, &.{
                .{ .attribute = .not_bold_or_dim },
                .{ .attribute = .default_foreground_color },
            }),
        }), &.{.{ .color = .{ .background = .{ .normal = .black } } }}, &.{.{ .attribute = .default_background_color }}),
    });

    const str = CSI.SGR.parseString("<du><u:30,255,120>Test<r><r>: <b:black><f:#ff00ef>Hello<r> <f:33><b>World<r><r><r>!");
    std.debug.print("{s}\n", .{str});
    std.debug.print("{s}\n", .{CSI.SGR.parseString("This: <b><f:red>\\<<r> should print without issues<r>")});

    std.debug.print("{s}\n", .{OSC.hyperlink("My link", "https://google.com/", null)});

    const Params = struct { id: u8 };
    std.debug.print("{s}\n", .{OSC.hyperlink("My link", "https://google.com/", Params{ .id = 1 })});
    std.debug.print("{s}\n", .{CSI.SGR.parseString("<b:hsi:0,0,0><f:hsv:0,255,255>Hello<r> <f:hsl:0.1,1,0.5>World<r><r>")});

    const parser = CSI.SGR.Parser(struct {
        pub const this_is_bold = .{ CSI.SGR.Attribute.bold, CSI.SGR.Attribute.not_bold_or_dim };
    });

    std.debug.print("{s}\n", .{parser.parseString("<this_is_bold>Im Bold!<r> Or not")});

    std.debug.print("{s}\n", .{tasai.comptimeStrip(str)});

    std.debug.print("{s}\n", .{try tasai.strip(allocator, str)});

    const stdout = std.io.getStdOut();
    const writer = stdout.writer();

    const c_p = ConfirmPrompt(.{ .message = "Are you alive?" });
    const answer1 = try c_p.run();
    try writer.print("Answer: {any}\n", .{answer1});

    const c_p2 = ConfirmPrompt(.{
        .message = "Are you alive?",
        .toggle = true,
    });
    const answer9 = try c_p2.run();
    try writer.print("Answer: {any}\n", .{answer9});

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

    const answer2 = try s_p.run();
    try writer.print("Answer: {s}\n", .{answer2});

    const s_p4 = SelectPrompt([]const u8, .{
        .message = "Pick",
        .multiple = true,
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

    const answer11 = try s_p4.run(allocator);
    try writer.print("Answer: {s}\n", .{answer11});

    const StringKV = KV([]const u8);

    const s_p2 = SelectPrompt(StringKV, .{
        .message = "Pick",
        .choices = &.{
            .{ .name = "Apple", .value = "I Love Apples" },
            .{ .name = "Orange", .value = "I Love Oranges" },
            .{ .name = "Grape", .value = "I Love Grapes" },
        },
    });

    const answer3 = try s_p2.run();
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

    const answer4 = try s_p3.run();
    try writer.print("Answer: {any}\n", .{answer4});

    const i_p = InputPrompt([]const u8, .{ .message = "What's your name?" });

    const answer5 = try i_p.run(allocator);
    try writer.print("Answer: {s}\n", .{answer5});

    const i_p2 = InputPrompt([]const u8, .{
        .message = "What's your password?",
        .password = true,
    });

    const answer6 = try i_p2.run(allocator);
    try writer.print("Answer: {s}\n", .{answer6});

    const i_p3 = InputPrompt(u8, .{ .message = "How old are you?" });

    const answer7 = try i_p3.run(allocator);
    try writer.print("Answer: {d}\n", .{answer7});

    const i_p4 = InputPrompt(f32, .{
        .message = "Give me a number",
        .invisible = true,
    });

    const answer8 = try i_p4.run(allocator);
    try writer.print("Answer: {d}\n", .{answer8});

    const i_p5 = InputPrompt([]const u8, .{
        .message = "Give me a list",
        .list = true,
    });

    const answer10 = try i_p5.run(allocator);
    try writer.print("Answer: {s}\n", .{answer10});
}
