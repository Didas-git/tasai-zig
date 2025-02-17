const std = @import("std");
const CSI = @import("./csi.zig");
const builtin = @import("builtin");

const windows = std.os.windows;
const is_windows = builtin.os.tag == .windows;

const Terminal = @This();

const WindowsModes = struct {
    codepage: c_uint,
    input: Windows.CONSOLE_MODE_INPUT,
    output: Windows.CONSOLE_MODE_OUTPUT,
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
                .input = .{},
                .output = .{},
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
    const original_stdin = try Windows.getConsoleMode(Windows.CONSOLE_MODE_INPUT, self.stdin.handle);
    const original_stdout = try Windows.getConsoleMode(Windows.CONSOLE_MODE_OUTPUT, self.stdout.handle);

    try Windows.setConsoleMode(self.stdin.handle, Windows.CONSOLE_MODE_INPUT{
        .EXTENDED_FLAGS = 1,
    });

    try Windows.setConsoleMode(self.stdout.handle, Windows.CONSOLE_MODE_OUTPUT{
        .PROCESSED_OUTPUT = 1,
        .VIRTUAL_TERMINAL_PROCESSING = 1,
        .DISABLE_NEWLINE_AUTO_RETURN = 1,
        .ENABLE_LVB_GRID_WORLDWIDE = 1,
    });

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
    Windows.setConsoleMode(self.stdin, self.modes.input) catch {};
    Windows.setConsoleMode(self.stdout, self.modes.output) catch {};
    windows.CloseHandle(self.stdin);
    windows.CloseHandle(self.stdout);
}

pub fn disableRawMode(self: Terminal) !void {
    switch (builtin.os.tag) {
        .windows => self.disableRawModeWindows(),
        else => try self.disableRawModePosix(),
    }
}

pub fn deinit(self: Terminal) !void {
    try self.stdout.writeAll(CSI.CUS);
    try self.disableRawMode();

    if (builtin.os.tag != .macos) std.posix.close(self.fd);
}

/// The handler has 4 bytes as special cases:
/// 252 - Arrow Up (ESC A | ESC[A | ESC O A)
/// 253 - Arrow Down (ESC B | ESC[B | ESC O B)
/// 254 - Arrow Right (ESC C | ESC[C | ESC O C)
/// 255 - Arrow Left (ESC D | ESC[D | ESC O D)
pub fn readInput(self: *Terminal, buf: []u8) !u8 {
    const is_ready, const bytes = try self.poll(buf);
    if (!is_ready) return error.FailedToPoll;

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

const poll = if (is_windows) pollWindows else pollPosix;

// This is an adaptation of the std implementation (https://github.com/ziglang/zig/blob/5b9b5e45cb710ddaad1a97813d1619755eb35a98/lib/std/io.zig#L610)
// to work without a fifo
fn pollPosix(self: *Terminal, buf: []u8) !struct { bool, usize } {
    const err_mask = std.posix.POLL.ERR | std.posix.POLL.NVAL | std.posix.POLL.HUP;

    var temp = [_]std.posix.pollfd{.{
        .fd = self.stdin.handle,
        .events = std.posix.POLL.IN,
        .revents = undefined,
    }};

    const events_len = try std.posix.poll(&temp, -1);

    var poll_fd = temp[0];

    if (events_len == 0) {
        return .{ poll_fd.fd != -1, 0 };
    }

    var amt: usize = 0;
    var keep_polling = false;
    if (poll_fd.revents & std.posix.POLL.IN != 0) {
        amt = std.posix.read(poll_fd.fd, buf) catch |err| switch (err) {
            error.BrokenPipe => 0,
            else => |e| return e,
        };
        if (amt == 0) {
            poll_fd.fd = -1;
        } else {
            keep_polling = true;
        }
    } else if (poll_fd.revents & err_mask != 0) {
        poll_fd.fd = -1;
    } else if (poll_fd.fd != -1) {
        keep_polling = true;
    }

    return .{ keep_polling, amt };
}

// This is a workaround while i cant think/find anything else
fn pollWindows(self: *Terminal, buf: []u8) !struct { bool, usize } {
    _ = buf;

    while (true) {
        var event_count: u32 = 0;
        var input_record: Windows.INPUT_RECORD = undefined;
        if (Windows.ReadConsoleInputW(self.stdin.handle, &input_record, 1, &event_count) == 0)
            return windows.unexpectedError(windows.kernel32.GetLastError());

        switch (input_record.EventType) {
            0x0010 => {
                return .{ true, input_record.Event.KeyEvent.uChar.AsciiChar };
            },
            else => continue,
        }
    }
}

// Thanks to libvaxis
// https://github.com/rockorager/libvaxis/blob/0eaf6226b2dd58720c5954d3646d6782e0c063f5/src/tty.zig#L281
const Windows = struct {
    fn getConsoleMode(comptime T: type, handle: windows.HANDLE) !T {
        var mode: u32 = undefined;
        if (windows.kernel32.GetConsoleMode(handle, &mode) == 0) return switch (windows.kernel32.GetLastError()) {
            .INVALID_HANDLE => error.InvalidHandle,
            else => |e| windows.unexpectedError(e),
        };
        return @bitCast(mode);
    }

    pub fn setConsoleMode(handle: windows.HANDLE, mode: anytype) !void {
        if (windows.kernel32.SetConsoleMode(handle, @bitCast(mode)) == 0) return switch (windows.kernel32.GetLastError()) {
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

    // From gitub.com/ziglibs/zig-windows-console

    const CHAR = extern union {
        UnicodeChar: windows.WCHAR,
        AsciiChar: windows.CHAR,
    };
    const KEY_EVENT_RECORD = extern struct {
        bKeyDown: windows.BOOL,
        wRepeatCount: windows.WORD,
        wVirtualKeyCode: windows.WORD,
        wVirtualScanCode: windows.WORD,
        uChar: CHAR,
        dwControlKeyState: windows.DWORD,
    };

    const MOUSE_EVENT_RECORD = extern struct {
        dwMousePosition: windows.COORD,
        dwButtonState: windows.DWORD,
        dwControlKeyState: windows.DWORD,
        dwEventFlags: windows.DWORD,
    };

    const WINDOW_BUFFER_SIZE_RECORD = extern struct {
        dwSize: windows.COORD,
    };

    const MENU_EVENT_RECORD = extern struct {
        dwCommandId: windows.UINT,
    };

    const FOCUS_EVENT_RECORD = extern struct {
        bSetFocus: windows.BOOL,
    };

    const EVENT = extern union {
        KeyEvent: KEY_EVENT_RECORD,
        MouseEvent: MOUSE_EVENT_RECORD,
        WindowBufferSizeEvent: WINDOW_BUFFER_SIZE_RECORD,
        MenuEvent: MENU_EVENT_RECORD,
        FocusEvent: FOCUS_EVENT_RECORD,
    };
    const INPUT_RECORD = extern struct {
        EventType: windows.WORD,
        Event: EVENT,
    };

    pub extern "kernel32" fn ReadConsoleInputW(hConsoleInput: windows.HANDLE, lpBuffer: *INPUT_RECORD, nLength: windows.DWORD, lpNumberOfEventsRead: *windows.DWORD) callconv(windows.WINAPI) windows.BOOL;
};
