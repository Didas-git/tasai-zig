const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "tasai",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);

    _ = b.addModule("tasai", .{
        .root_source_file = b.path("src/tasai.zig"),
    });

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // https://kristoff.it/blog/improving-your-zls-experience/
    const exe_check = b.addExecutable(.{
        .name = "tasai",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const check = b.step("check", "Check if foo compiles");
    check.dependOn(&exe_check.step);

    const export_test = b.addTest(.{
        .root_source_file = b.path("src/tasai.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_export_test = b.addRunArtifact(export_test);
    const test_step = b.step("test", "Run unit tests on the exports");
    test_step.dependOn(&run_export_test.step);
}
