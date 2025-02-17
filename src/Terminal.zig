const std = @import("std");
const CSI = @import("./csi.zig");
const builtin = @import("builtin");

const windows = std.os.windows;
const is_windows = builtin.os.tag == .windows;

const Terminal = @This();

const WindowsModes = struct {
    codepage: c_uint,
    input: windows.DWORD,
    output: windows.DWORD,
};

fd: if (is_windows) void else std.posix.fd_t,
termios: if (is_windows) void else ?std.posix.termios,
modes: if (is_windows) WindowsModes else void,
stdout: std.fs.File,
stdin: std.fs.File,

pub fn init() !Terminal {
    return switch (builtin.os.tag) {
        .windows => .{
            .fd = {},
            .termios = {},
            .modes = .{
                .codepage = 0,
                .input = 0,
                .output = 0,
            },
            .stdout = std.io.getStdOut(),
            .stdin = std.io.getStdIn(),
        },
        else => .{
            .fd = try std.posix.open("/dev/tty", .{ .ACCMODE = .RDWR }, 0),
            .termios = null,
            .modes = {},
            .stdout = std.io.getStdOut(),
            .stdin = std.io.getStdIn(),
        },
    };
}

fn enableRawModePosix(self: *Terminal) !void {
    var termios = try std.posix.tcgetattr(self.fd);
    const original_termios = termios;

    // cspell:disable
    termios.iflag.IGNBRK = false;
    termios.iflag.PARMRK = false;
    termios.iflag.INLCR = false;
    termios.iflag.IGNCR = false;
    termios.iflag.BRKINT = false;
    termios.iflag.ICRNL = false;
    termios.iflag.INPCK = false;
    termios.iflag.ISTRIP = false;
    termios.iflag.IXON = false;

    termios.oflag.OPOST = false;

    termios.lflag.ECHONL = false;
    termios.lflag.ECHO = false;
    termios.lflag.ICANON = false;
    termios.lflag.IEXTEN = false;
    termios.lflag.ISIG = false;

    termios.cflag.PARENB = false;
    termios.cflag.CSIZE = .CS8;
    // cspell:enable

    termios.cc[@intFromEnum(std.posix.V.MIN)] = 1;
    termios.cc[@intFromEnum(std.posix.V.TIME)] = 0;

    try std.posix.tcsetattr(self.fd, .FLUSH, termios);
    self.termios = original_termios;
}

fn enableRawModeWindows(self: *Terminal) !void {
    const original_codepage = windows.kernel32.GetConsoleOutputCP();
    const original_stdin = try Windows.getConsoleMode(self.stdin.handle);
    const original_stdout = try Windows.getConsoleMode(self.stdout.handle);

    try Windows.setConsoleMode(self.stdin.handle, original_stdin | @as(windows.DWORD, @bitCast(Windows.CONSOLE_MODE_INPUT{
        .VIRTUAL_TERMINAL_INPUT = 1,
        .EXTENDED_FLAGS = 1,
    })));

    try Windows.setConsoleMode(self.stdout.handle, @as(windows.DWORD, @bitCast(Windows.CONSOLE_MODE_OUTPUT{
        .PROCESSED_OUTPUT = 1,
        .VIRTUAL_TERMINAL_PROCESSING = 1,
    })));

    if (windows.kernel32.SetConsoleOutputCP(65001) == 0)
        return windows.unexpectedError(windows.kernel32.GetLastError());

    self.modes = .{
        .codepage = original_codepage,
        .input = original_stdin,
        .output = original_stdout,
    };
}

pub fn enableRawMode(self: *Terminal) !void {
    switch (builtin.os.tag) {
        .windows => try self.enableRawModeWindows(),
        else => try self.enableRawModePosix(),
    }
}

fn disableRawModePosix(self: Terminal) !void {
    if (self.termios) |termios| {
        try std.posix.tcsetattr(self.fd, .NOW, termios);
    }
}

fn disableRawModeWindows(self: Terminal) !void {
    _ = windows.kernel32.SetConsoleOutputCP(self.modes.codepage);
    Windows.setConsoleMode(self.stdin.handle, self.modes.input) catch {};
    Windows.setConsoleMode(self.stdout.handle, self.modes.output) catch {};
}

pub fn disableRawMode(self: Terminal) !void {
    switch (builtin.os.tag) {
        .windows => try self.disableRawModeWindows(),
        else => try self.disableRawModePosix(),
    }
}

pub fn deinit(self: Terminal) !void {
    try self.stdout.writeAll(CSI.CUS);
    try self.disableRawMode();

    if (builtin.os.tag != .macos and builtin.os.tag != .windows) std.posix.close(self.fd);
}

/// The handler has 4 bytes as special cases:
/// 252 - Arrow Up (ESC A | ESC[A | ESC O A)
/// 253 - Arrow Down (ESC B | ESC[B | ESC O B)
/// 254 - Arrow Right (ESC C | ESC[C | ESC O C)
/// 255 - Arrow Left (ESC D | ESC[D | ESC O D)
pub fn readInput(self: *Terminal, buf: []u8) !u8 {
    const bytes = try self.read(buf);

    if (bytes > 1) {
        if (buf[0] == std.ascii.control_code.esc) {
            return switch (buf[1]) {
                'A' => @as(u8, 252),
                'B' => @as(u8, 253),
                'C' => @as(u8, 254),
                'D' => @as(u8, 255),
                '[', 'O' => switch (buf[2]) {
                    'A' => @as(u8, 252),
                    'B' => @as(u8, 253),
                    'C' => @as(u8, 254),
                    'D' => @as(u8, 255),
                    else => return error.UnsupportedEscapeCode,
                },
                else => return error.UnsupportedEscapeCode,
            };
        } else {
            return error.UnsupportedValue;
        }
    } else {
        return buf[0];
    }
}

fn read(self: *Terminal, buf: []u8) !usize {
    return std.posix.read(self.stdin.handle, buf) catch |err| switch (err) {
        error.BrokenPipe => 0,
        else => |e| return e,
    };
}

// Thanks to libvaxis
// https://github.com/rockorager/libvaxis/blob/0eaf6226b2dd58720c5954d3646d6782e0c063f5/src/tty.zig#L281
const Windows = struct {
    fn getConsoleMode(handle: windows.HANDLE) !windows.DWORD {
        var mode: u32 = undefined;
        if (windows.kernel32.GetConsoleMode(handle, &mode) == 0) return switch (windows.kernel32.GetLastError()) {
            .INVALID_HANDLE => error.InvalidHandle,
            else => |e| windows.unexpectedError(e),
        };
        return @bitCast(mode);
    }

    pub fn setConsoleMode(handle: windows.HANDLE, mode: windows.DWORD) !void {
        if (windows.kernel32.SetConsoleMode(handle, mode) == 0) return switch (windows.kernel32.GetLastError()) {
            .INVALID_HANDLE => error.InvalidHandle,
            else => |e| windows.unexpectedError(e),
        };
    }
    const CONSOLE_MODE_INPUT = packed struct(u32) {
        PROCESSED_INPUT: u1 = 0,
        LINE_INPUT: u1 = 0,
        ECHO_INPUT: u1 = 0,
        WINDOW_INPUT: u1 = 0,
        MOUSE_INPUT: u1 = 0,
        INSERT_MODE: u1 = 0,
        QUICK_EDIT_MODE: u1 = 0,
        EXTENDED_FLAGS: u1 = 0,
        AUTO_POSITION: u1 = 0,
        VIRTUAL_TERMINAL_INPUT: u1 = 0,
        _: u22 = 0,
    };
    const CONSOLE_MODE_OUTPUT = packed struct(u32) {
        PROCESSED_OUTPUT: u1 = 0,
        WRAP_AT_EOL_OUTPUT: u1 = 0,
        VIRTUAL_TERMINAL_PROCESSING: u1 = 0,
        DISABLE_NEWLINE_AUTO_RETURN: u1 = 0,
        ENABLE_LVB_GRID_WORLDWIDE: u1 = 0,
        _: u27 = 0,
    };
};
