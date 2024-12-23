const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const run_step = b.step("run", "Run the application");

    const win32 = b.dependency("zigwin32", .{});

    const exe = b.addExecutable(.{
        .name = "trayicon",
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/main.zig"),
    });
    exe.root_module.addImport("win32", win32.module("zigwin32"));
    // exe.subsystem = .Windows;

    const run_exe = b.addRunArtifact(exe);
    run_step.dependOn(&run_exe.step);

    b.installArtifact(exe);
}
