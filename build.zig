const std = @import("std");

/// ==================================================
///             modules and dependencies
/// ==================================================
fn Aids(b: *std.Build) struct { module: *std.Build.Module } {
    const mod = b.addModule("aids", .{
        .root_source_file = b.path("src/aids/aids.zig"),
    });
    return .{ .module = mod, };
}

fn Sqids(b: *std.Build) struct { module: *std.Build.Module } {
    const sqids_dep = b.dependency("sqids", .{});
    const mod = sqids_dep.module("sqids");
    return .{ .module = mod, };
}

fn Raylib(b: *std.Build, target: std.Build.ResolvedTarget ,optimize: std.builtin.OptimizeMode) struct { module: *std.Build.Module, artifact: *std.Build.Step.Compile } {
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

    const raylib = raylib_dep.module("raylib"); // main raylib module
    //const raygui = raylib_dep.module("raygui"); // raygui module
    const raylib_artifact = raylib_dep.artifact("raylib"); // raylib C library
    return .{
        .module= raylib,
        .artifact= raylib_artifact,
    };
}

/// ==================================================
///                     programs
/// ==================================================
pub fn Program(b: *std.Build, opts: std.Build.ExecutableOptions) struct { exe: *std.Build.Step.Compile, module: *std.Build.Module } {
    const server_exe = b.addExecutable(opts);
    server_exe.root_module.addImport("aids", Aids(b).module);

    return .{
        .exe = server_exe,
        .module = &server_exe.root_module,
    };
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const raylib = Raylib(b, target, optimize);
    const sqids  = Sqids(b);

    const server = Program(b, .{
        .name="tsock-server",
        .root_source_file = b.path("./src/server/main.zig"),
        .target = target,
        .optimize = optimize
    });
    server.module.addImport("sqids", sqids.module);

    b.installArtifact(server.exe);
    const run_server_exe = b.addRunArtifact(server.exe);

    const run_server_step = b.step("run-server", "Run the SERVER");
    // add command line arguments
    if (b.args) |args| {
        run_server_exe.addArgs(args);
    }
    run_server_step.dependOn(&run_server_exe.step);

    // this target does not work with raylib
    const client = Program(b, .{
        .name = "tsockm-client",
        .root_source_file = b.path("src/client/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    client.exe.linkLibrary(raylib.artifact);
    client.module.addImport("raylib", raylib.module);
    //client_exe.root_module.addImport("raygui", raylib.raygui);

    //b.installArtifact(client_exe);
    const build_client = b.addInstallArtifact(client.exe, .{});
    const build_client_step = b.step("client", "Build the client");
    build_client_step.dependOn(&build_client.step);
    const run_client_exe = b.addRunArtifact(client.exe);
    // add command line arguments
    if (b.args) |args| {
        run_client_exe.addArgs(args);
    }
    const run_client_step = b.step("run", "Run the CLIENT");
    run_client_step.dependOn(&run_client_exe.step);
}
