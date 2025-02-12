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
const prompts = @import("tasai").prompts;

var buf: [64]u8 = undefined;
var fba2 = std.heap.FixedBufferAllocator.init(&buf);
const prompt = prompts.ConfirmPrompt(.{ .message = "Are you alive?" });

const std_out = std.io.getStdOut();
const answer = try prompt.run(fba2.allocator());
const writer = std_out.writer();

try writer.print("Answer: {s}\n", .{if (answer) "true" else "false"});
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