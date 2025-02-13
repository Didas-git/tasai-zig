const std = @import("std");
const CSI = @import("./csi.zig");

pub fn RawTerminal(comptime handle_control_codes: bool) type {
    const StaticFifo = std.fifo.LinearFifo(u8, .{ .Static = 8 });
    return struct {
        fifo: StaticFifo,
        tty: std.fs.File,
        termios: std.posix.termios,
        stdout: std.fs.File = std.io.getStdOut(),
        stdin: std.fs.File = std.io.getStdIn(),

        pub fn init() !RawTerminal(handle_control_codes) {
            const file = try std.fs.openFileAbsolute("/dev/tty", .{
                .mode = .read_write,
                .allow_ctty = true,
            });

            var termios = try std.posix.tcgetattr(file.handle);
            const original_termios = termios;

            // https://github.com/xyaman/mibu/blob/b001662c929e2719ee24be585a3120640f946337/src/term.zig#L19
            // cspell:disable
            termios.iflag.BRKINT = false;
            termios.iflag.ICRNL = false;
            termios.iflag.INPCK = false;
            termios.iflag.ISTRIP = false;
            termios.iflag.IXON = false;

            termios.oflag.OPOST = false;

            termios.lflag.ECHO = false;
            termios.lflag.ICANON = false;
            termios.lflag.IEXTEN = false;
            termios.lflag.ISIG = false;

            termios.cflag.CSIZE = .CS8;
            // cspell:enable

            termios.cc[@intFromEnum(std.posix.V.MIN)] = 1;
            termios.cc[@intFromEnum(std.posix.V.TIME)] = 0;

            try std.posix.tcsetattr(file.handle, .NOW, termios);

            return .{
                .fifo = StaticFifo.init(),
                .tty = file,
                .termios = original_termios,
            };
        }

        pub fn deinit(self: RawTerminal(handle_control_codes)) !void {
            try self.stdout.writeAll(CSI.CUS);
            try std.posix.tcsetattr(self.tty.handle, .NOW, self.termios);
            self.fifo.deinit();
        }

        /// The handler has 4 bytes as special cases:
        /// 252 - Arrow Up (ESC A | ESC[A | ESC O A)
        /// 253 - Arrow Down (ESC B | ESC[B | ESC O B)
        /// 254 - Arrow Right (ESC C | ESC[C | ESC O C)
        /// 255 - Arrow Left (ESC D | ESC[D | ESC O D)
        pub fn readInput(self: *RawTerminal(handle_control_codes), comptime T: type, handler: fn (byte: u8) anyerror!?T) !T {
            var buf: [8]u8 = undefined;
            while (true) {
                const isReady = try self.poll();
                if (!isReady) return error.FailedToPoll;
                const bytes = self.fifo.read(&buf);

                if (bytes > 1) {
                    if (buf[0] == std.ascii.control_code.esc) {
                        const byte = switch (buf[1]) {
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

                        if (try handler(byte)) |val| {
                            return val;
                        }
                    } else {
                        return error.UnsupportedValue;
                    }
                } else if (handle_control_codes) {
                    switch (buf[0]) {
                        std.ascii.control_code.etx => {
                            try self.deinit();
                            std.process.abort();
                        },
                        else => {
                            if (try handler(buf[0])) |val| {
                                return val;
                            }
                        },
                    }
                } else {
                    if (try handler(buf[0])) |val| {
                        return val;
                    }
                }

                buf = undefined;
            }
        }

        // This is an adaptation of the std implementation (https://github.com/ziglang/zig/blob/5b9b5e45cb710ddaad1a97813d1619755eb35a98/lib/std/io.zig#L610)
        // to work with a static fifo instead
        fn poll(self: *RawTerminal(handle_control_codes)) !bool {
            const err_mask = std.posix.POLL.ERR | std.posix.POLL.NVAL | std.posix.POLL.HUP;

            var temp = [_]std.posix.pollfd{.{
                .fd = self.stdin.handle,
                .events = std.posix.POLL.IN,
                .revents = undefined,
            }};

            const events_len = try std.posix.poll(&temp, -1);

            var poll_fd = temp[0];

            if (events_len == 0) {
                return poll_fd.fd != -1;
            }

            var keep_polling = false;
            if (poll_fd.revents & std.posix.POLL.IN != 0) {
                const buf = try self.fifo.writableWithSize(8);
                const amt = std.posix.read(poll_fd.fd, buf) catch |err| switch (err) {
                    error.BrokenPipe => 0,
                    else => |e| return e,
                };
                self.fifo.update(amt);
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

            return keep_polling;
        }
    };
}
