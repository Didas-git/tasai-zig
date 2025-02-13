# Tasai

Tasai is a zig library that provides multiple comptime utilities to colorize your terminal messages, logs, and much more, if it supports [ANSI escape codes](https://en.wikipedia.org/wiki/ANSI_escape_code) then tasai will work.

Let's make our terminals more colorful (多彩).

# Installation

Tasai is available using the `zig fetch` command.

```sh
zig fetch --save git+https://github.com/Didas-git/tasai-zig
```

To add it yo your project, after running the command above add the following to your build file:

```zig
const tasai = b.dependency("tasai", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("tasai", tasai.module("tasai"));
```

# Usage

## Prompting

### Confirm Prompt

```zig
const prompt = @import("tasai").prompt;

const prompt = prompt.Confirm(.{ .message = "Are you alive?" });

const std_out = std.io.getStdOut();
const answer = try prompt.run();
const writer = std_out.writer();

try writer.print("Answer: {any}\n", .{answer});
```

### Select Prompt

#### Using Strings

```zig
const prompt = @import("tasai").prompt;

const prompt = prompt.Select([]const u8, .{ 
    .message = "Pick one", 
    .choices = &.{
        "Apples",
        "Oranges",
        "Grapes",
    }, 
});

const std_out = std.io.getStdOut();
const answer = try prompt.run();
const writer = std_out.writer();

try writer.print("Answer: {s}\n", .{answer});
```

#### Using Key-Value pairs

Using key value pairs allows you to display a message and get a completely different output from it the selection.

```zig
const tasai = @import("tasai");
const prompt = tasai.prompt;

const StringKV = tasai.KV([]const u8);

const prompt = prompt.Select(StringKV, .{ 
    .message = "Pick one", 
    .choices = &.{
        .{ .name = "Apple", .value = "I Love Apples" },
        .{ .name = "Orange", .value = "I Love Oranges" },
        .{ .name = "Grape", .value = "I Love Grapes" },
    }, 
});

const std_out = std.io.getStdOut();
const answer = try prompt.run();
const writer = std_out.writer();

try writer.print("Answer: {s}\n", .{answer});
```

#### Accepting multiple choices

To accept multiple options all you need to do is pass in `.multiple = true` to the options and pass an `Allocator` to the `run` function.

```zig
const prompt = @import("tasai").prompt;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();
const prompt = prompts.Select([]const u8, .{ 
    .message = "Pick one",
    .multiple = true,
    .choices = &.{
        "Apples",
        "Oranges",
        "Grapes",
    }, 
});

const std_out = std.io.getStdOut();
const answer = try prompt.run(allocator);
const writer = std_out.writer();

try writer.print("Answer: {s}\n", .{answer});
```

### Input Prompt

Input prompts are very versatile and work with both strings and numbers (ints and floats).
They can be made "invisible" (doesn't show what the user is currently typing) and also work as password input by setting the respective options.

```zig
const prompt = @import("tasai").prompt;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();
const prompt = prompt.Input([]const u8, .{ .message = "Who are you?" });

const std_out = std.io.getStdOut();
const answer = try prompt.run(allocator);
const writer = std_out.writer();

try writer.print("Answer: {any}\n", .{answer});
```

## Coloring

Tasai provides 2 different comptime-only apis for dealing with colors.

### String API

The available tags are documented on the function itself.

```zig
const print = @import("std").debug.print;
const SGR = @import("tasai").CSI.SGR;

// Print "hello" in pink (with a hex code)
// and "world" in bold blue (the blue comes from the 8bit ANSI codes)
print(SGR.parseString("<f:#ff00ef>hello<r> <f:33><b>world<r><r>\n"), .{});

// Escaping '<'
print(SGR.parseString("This will print <f:red>\\<<r> in red\n"), .{});
```

### Verbose API

While this API is rather overkill it can be rather useful given it includes all* the SGR codes and is not limited to a few set of them.

```zig
const print = @import("std").debug.print;
const SGR = @import("tasai").CSI.SGR;

// Print "hello" in pink (with a hex code) and "world" in bold blue
print("{s} {s}\n", .{
    SGR.verboseFormat("Hello", &.{
            .{ .Color = .{ .Foreground = .{ .@"24bit" = .{ .r = 255, .g = 0, .b = 239 } } } },
        }, &.{
            .{ .Attribute = .Default_Foreground_Color },
        }),
    SGR.verboseFormat("World", &.{
            .{ .Attribute = .Bold },
            .{ .Color = .{ .Foreground = .{ .@"8bit" = 33 } } },
        }, &.{
            .{ .Attribute = .Not_Bold_Or_Dim },
            .{ .Attribute = .Default_Foreground_Color },
        }),
});
```