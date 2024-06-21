const std = @import("std");
const server_version = @import("./src/server/main.zig").SERVER_VERSION;
const client_version = @import("./src/client/main.zig").CLIENT_VERSION;
const rlz = @import("raylib-zig");

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

fn Raylib(b: *std.Build, target: std.Build.ResolvedTarget ,optimize: std.builtin.OptimizeMode) struct { module: *std.Build.Module, artifact: *std.Build.Step.Compile, dependency: *std.Build.Dependency } {
    const raylib_dep = b.dependency("raylib-zig", .{
        .target = target,
        .optimize = optimize,
        .linux_display_backend = .X11,
    });

    const raylib = raylib_dep.module("raylib"); // main raylib module
    const raylib_artifact = raylib_dep.artifact("raylib"); // raylib C library
    return .{
        .module= raylib,
        .dependency = raylib_dep,
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

fn release_build_server(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, step: *std.Build.Step) !void {
    const sqids  = Sqids(b);

    const arch = target.result.linuxTriple(b.allocator) catch |err| {
        std.log.err("59::release_build_server: {any}", .{err});
        std.posix.exit(1);
    };

    const pname = std.fmt.allocPrint(b.allocator, "tsockm-server-{s}-{s}", .{server_version, arch}) catch |err| {
        std.log.err("64::release_build_server: {any}", .{err});
        std.posix.exit(1);
    };

    const server = Program(b, .{
        .name=pname,
        .root_source_file = b.path("./src/server/main.zig"),
        .target = target,
        .optimize = optimize
    });
    server.module.addImport("sqids", sqids.module);

    const target_tripple = try target.result.linuxTriple(b.allocator);
    const out_dir_path = try std.fmt.allocPrint(b.allocator, "tsock-server-{s}-{s}", .{server_version, target_tripple}); 

    const target_output = b.addInstallArtifact(server.exe, .{
        .dest_dir = .{
            .override = .{
                .custom = out_dir_path,
            },
        },
    });

    step.dependOn(&target_output.step);
}

fn build_client_for_all_targets(b: *std.Build, target: std.Build.ResolvedTarget, step: *std.Build.Step) !void {
    //const targets: []const std.Target.Query = &.{
    //    //.{ .cpu_arch = .aarch64, .os_tag = .macos },
    //    //.{ .cpu_arch = .aarch64, .os_tag = .linux },
    //    .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu },
    //    //.{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .musl },
    //    //.{ .cpu_arch = .x86_64, .os_tag = .windows },
    //};
    //for (targets) |t| {
    var ldbs: rlz.LinuxDisplayBackend = .X11; 
    const ldb_opt = b.option([]const u8, "platform", "build platform (X11 or Wayland)"); 
    if (ldb_opt) |ldb| {
        if (std.mem.eql(u8, ldb, "X11")) {
            ldbs = .X11;
        } else if (std.mem.eql(u8, ldb, "Wayland")) {
            ldbs = .Wayland;
        }
    }
    //for (ldbs) |linux_display_backend| {
    //}
        const raylib_dep = b.dependency("raylib-zig", .{
            .target = target,
            .optimize = .ReleaseSafe,
            .linux_display_backend = ldbs,
        });

        const raylib = raylib_dep.module("raylib"); // main raylib module
        const raylib_artifact = raylib_dep.artifact("raylib"); // raylib C library

        const client = Program(b, .{
            .name = "tsockm-client",
            .root_source_file = b.path("src/client/main.zig"),
            .target = target,
            .optimize = .ReleaseSafe,
        });
        const raygui = raylib_dep.module("raygui"); // raygui module
        client.exe.linkLibrary(raylib_artifact);
        client.module.addImport("raylib", raylib);
        client.module.addImport("raygui", raygui);

        const target_tripple = try target.result.linuxTriple(b.allocator);
        const out_dir_path = try std.fmt.allocPrint(b.allocator, "tsock-client-{s}-{s}", .{target_tripple, @tagName(ldbs)}); 

        const target_output = b.addInstallArtifact(client.exe, .{
            .dest_dir = .{
                .override = .{
                    .custom = out_dir_path,
                },
            },
        });
        step.dependOn(&target_output.step);
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const raylib_optimize = b.option(
        std.builtin.OptimizeMode,
        "raylib-optimize",
        "Prioritize performance, safety, or binary size (-O flag), defaults to value of optimize option",
    ) orelse .ReleaseSafe;

    const raylib = Raylib(b, target, raylib_optimize);
    const sqids  = Sqids(b);

    const server = Program(b, .{
        .name="tsock-server",
        .root_source_file = b.path("./src/server/main.zig"),
        .target = target,
        .optimize = optimize
    });
    server.module.addImport("sqids", sqids.module);

    const server_art = b.addInstallArtifact(server.exe, .{});
    const run_server_exe = b.addRunArtifact(server.exe);

    const run_server_step = b.step("dev-server", "Run the SERVER");
    // add command line arguments
    if (b.args) |args| {
        run_server_exe.addArgs(args);
    }
    run_server_step.dependOn(&server_art.step);
    run_server_step.dependOn(&run_server_exe.step);

    // this target does not work with raylib
    const client = Program(b, .{
        .name = "tsockm-client",
        .root_source_file = b.path("src/client/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const raygui = raylib.dependency.module("raygui"); // raygui module
    client.exe.linkLibrary(raylib.artifact);
    client.module.addImport("raylib", raylib.module);
    client.module.addImport("raygui", raygui);

    //b.installArtifact(client_exe);
    const build_client = b.addInstallArtifact(client.exe, .{});
    const run_client_exe = b.addRunArtifact(client.exe);
    // add command line arguments
    if (b.args) |args| {
        run_client_exe.addArgs(args);
    }
    const run_client_step = b.step("dev-client", "Run the CLIENT");
    run_client_step.dependOn(&build_client.step);
    run_client_step.dependOn(&run_client_exe.step);

    const tmp = b.step("release-server", "release build server");
    _ = release_build_server(b, target, optimize, tmp) catch 1;

    const tmp2 = b.step("release-client", "release build server");
    _ = build_client_for_all_targets(b, target, tmp2) catch 1;
}
