const std = @import("std");

pub fn build(b: *std.Build) void {

    const sqids_dep = b.dependency("sqids", .{});

    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const raylib_optimize = b.option(
        std.builtin.OptimizeMode,
        "raylib-optimize",
        "Prioritize performance, safety, or binary size (-O flag), defaults to value of optimize option",
    ) orelse optimize;
    const raylib_dep = b.dependency("raylib-zig", .{
        .target = target,
        .optimize = raylib_optimize,
        .linux_display_backend = .X11,
    });

    const lib_mod = b.addModule("aids", .{
        .root_source_file = b.path("src/aids/root.zig"),
    });
    const sqids_mod = sqids_dep.module("sqids");
    const raylib = raylib_dep.module("raylib"); // main raylib module
    const raygui = raylib_dep.module("raygui"); // raygui module
    const raylib_artifact = raylib_dep.artifact("raylib"); // raylib C library

    const server_exe = b.addExecutable(.{
        .name = "tsockm-server",
        .root_source_file = b.path("src/server/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    server_exe.root_module.addImport("aids", lib_mod);
    server_exe.root_module.addImport("sqids", sqids_mod);

    b.installArtifact(server_exe);
    const run_server_exe = b.addRunArtifact(server_exe);

    const run_server_step = b.step("server", "Run the SERVER");
    // add command line arguments
    if (b.args) |args| {
        run_server_exe.addArgs(args);
    }
    run_server_step.dependOn(&run_server_exe.step);

    // this target does not work with raylib
    const client_exe = b.addExecutable(.{
        .name = "tsockm-client",
        .root_source_file = b.path("src/client/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    client_exe.linkLibrary(raylib_artifact);
    client_exe.root_module.addImport("raylib", raylib);
    client_exe.root_module.addImport("raygui", raygui);
    client_exe.root_module.addImport("aids", lib_mod);

    b.installArtifact(client_exe);
    const run_client_exe = b.addRunArtifact(client_exe);
    // add command line arguments
    if (b.args) |args| {
        run_client_exe.addArgs(args);
    }
    const run_client_step = b.step("client", "Run the CLIENT");
    run_client_step.dependOn(&run_client_exe.step);
}
