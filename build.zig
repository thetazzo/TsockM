const std = @import("std");
const server_version = @import("./src/server/main.zig").SERVER_VERSION;
const client_version = @import("./src/client/main.zig").CLIENT_VERSION;
const rlz = @import("raylib-zig");

const ASSETS_FOLDER_PATH = "./assets/";

/// ==================================================
///             modules and dependencies
/// ==================================================

//TODO: convert to static library if possible
fn Aids(b: *std.Build) struct { module: *std.Build.Module } {
    const mod = b.addModule("aids", .{
        .root_source_file = b.path("src/aids/aids.zig"),
    });
    return .{
        .module = mod,
    };
}

const MADL = struct {
    module: *std.Build.Module,
    artifact: *std.Build.Step.Compile,
    dependency: *std.Build.Dependency,
    LDB: rlz.LinuxDisplayBackend,
};
fn Raylib(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, ldb: rlz.LinuxDisplayBackend) MADL {
    const raylib_dep = b.dependency("raylib-zig", .{
        .target = target,
        .optimize = optimize,
        .linux_display_backend = ldb,
    });
    const raylib = raylib_dep.module("raylib");
    const raylib_artifact = raylib_dep.artifact("raylib");
    // web export not supported yet
    // web exports are completely separate
    // if (target.query.os_tag == .emscripten) {}
    return .{
        .module = raylib,
        .dependency = raylib_dep,
        .artifact = raylib_artifact,
        .LDB = ldb,
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

fn STEP_server_dev(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, step: *std.Build.Step) !void {
    const target_triple = try target.result.linuxTriple(b.allocator);
    std.log.info("Building SERVER-dev version `{s}` for target `{s}`", .{ server_version, target_triple });
    const server_program = Program(b, .{
        .name = "tsockm-server",
        .root_source_file = b.path("./src/server/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    // Build server
    const server_artifact = b.addInstallArtifact(server_program.exe, .{});
    // Run server
    const run_server_artifact = b.addRunArtifact(server_program.exe);
    // add command line arguments to run server step
    if (b.args) |args| {
        run_server_artifact.addArgs(args);
    }
    step.dependOn(&server_artifact.step);
    step.dependOn(&run_server_artifact.step);
    std.debug.print("\u{001B}[32m" ++ "SUCCESS\n" ++ "\u{001B}[39m", .{});
}

fn STEP_testing_server(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, step: *std.Build.Step) !void {
    const target_triple = try target.result.linuxTriple(b.allocator);
    std.log.info("Building SERVER-testing version `{s}` for target `{s}`", .{ server_version, target_triple });
    const server_program = Program(b, .{
        .name = "tsockm-server",
        .root_source_file = b.path("./src/server/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    // Build server
    const server_artifact = b.addInstallArtifact(server_program.exe, .{});
    // Run server
    const run_server_artifact = b.addRunArtifact(server_program.exe);
    // add command line arguments to run server step
    run_server_artifact.addArgs(&.{ "start", "--tester" });
    step.dependOn(&server_artifact.step);
    step.dependOn(&run_server_artifact.step);
    std.debug.print("\u{001B}[32m" ++ "SUCCESS\n" ++ "\u{001B}[39m", .{});
}

fn STEP_client_dev(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, step: *std.Build.Step, raylib: MADL) !void {
    const target_tripple = try target.result.linuxTriple(b.allocator);
    std.log.info("Building CLIENT-dev version `{s}` for target `{s}`", .{ server_version, target_tripple });
    // this target does not work with raylib
    const client_program = Program(b, .{
        .name = "tsockm-client",
        .root_source_file = b.path("src/client/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const raygui = raylib.dependency.module("raygui"); // raygui module
    client_program.exe.linkLibrary(raylib.artifact);
    client_program.module.addImport("raylib", raylib.module);
    client_program.module.addImport("raygui", raygui);
    //b.installArtifact(client_exe);
    const build_client_artifact = b.addInstallArtifact(client_program.exe, .{});
    const run_client_artifact = b.addRunArtifact(client_program.exe);
    // add command line arguments
    if (b.args) |args| {
        run_client_artifact.addArgs(args);
    }
    step.dependOn(&build_client_artifact.step);
    step.dependOn(&run_client_artifact.step);
    std.debug.print("\u{001B}[32m" ++ "SUCCESS\n" ++ "\u{001B}[39m", .{});
}

fn STEP_release_server(b: *std.Build, targets: []const std.Target.Query, step: *std.Build.Step) !void {
    for (targets) |t| {
        const target = b.resolveTargetQuery(t);
        const target_tripple = try target.result.linuxTriple(b.allocator);
        std.log.info("Building SERVER version `{s}` for target `{s}`", .{ server_version, target_tripple });
        const server = Program(b, .{
            .name = "tsockm-server",
            .root_source_file = b.path("./src/server/main.zig"),
            .target = target,
            .optimize = .ReleaseSafe,
        });
        const out_dir_path = try std.fmt.allocPrint(b.allocator, "server/{s}/tsockm-server-{s}-{s}", .{
            server_version,
            server_version,
            target_tripple,
        });
        const server_install = b.addInstallArtifact(server.exe, .{
            .dest_dir = .{
                .override = .{
                    .custom = out_dir_path,
                },
            },
        });
        step.dependOn(&server_install.step);
        std.debug.print("\u{001B}[32m" ++ "SUCCESS\n" ++ "\u{001B}[39m", .{});
    }
}

fn STEP_release_client(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, step: *std.Build.Step, raylib: MADL) !void {
    const target_tripple = try target.result.linuxTriple(b.allocator);
    std.log.info("Building CLIENT version `{s}` for target `{s}`", .{ client_version, target_tripple });
    // Client release platform option
    //     * what display manager to use
    const client_program = Program(b, .{
        .name = "tsockm-client",
        .root_source_file = b.path("./src/client/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    client_program.exe.linkLibrary(raylib.artifact);
    client_program.exe.root_module.addImport("raylib", raylib.module);
    const out_dir_path = try std.fmt.allocPrint(b.allocator, "client/{s}/tsockm-client-{s}-{s}-{s}", .{ client_version, client_version, target_tripple, @tagName(raylib.LDB) });
    const full_out_path = try std.fmt.allocPrintZ(b.allocator, "zig-out/{s}", .{out_dir_path});
    const client_install = b.addInstallArtifact(client_program.exe, .{
        .dest_dir = .{
            .override = .{
                .custom = out_dir_path,
            },
        },
    });
    step.dependOn(&client_install.step);
    // copy fonts to release build
    {
        const assets_path = std.fmt.comptimePrint("{s}/fonts", .{ASSETS_FOLDER_PATH});
        const cpa = b.addSystemCommand(&.{ "cp", "-r", assets_path, full_out_path });
        cpa.step.name = "copy font assets";
        cpa.step.dependOn(&client_install.step);
        step.dependOn(&cpa.step);
    }
    std.debug.print("\u{001B}[32m" ++ "SUCCESS\n" ++ "\u{001B}[39m", .{});
}

fn addTestRunner(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    root_path: []const u8,
) *std.Build.Step.Run {
    const server_unit_tests = b.addTest(.{
        .root_source_file = b.path(root_path),
        .target = target,
        .optimize = optimize,
    });
    server_unit_tests.root_module.addImport("aids", Aids(b).module);
    const run_server_unit_test = b.addRunArtifact(server_unit_tests);
    return run_server_unit_test;
}

// TODO: client and server versioning
//          * have a file where all versins get written
//          * check that no already existing versions get overwritten
pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const ldb_opt = b.option(rlz.LinuxDisplayBackend, "RLDB", "linux display backend that Raylib should use") orelse .X11;
    const raylib = Raylib(b, target, optimize, ldb_opt);

    const dev_server_step = b.step("dev-server", "Use server for development run");
    _ = STEP_server_dev(b, target, optimize, dev_server_step) catch |err| {
        std.log.err("build::STEP_server_dev: {any}", .{err});
        std.posix.exit(1);
    };

    const dev_client_step = b.step("dev-client", "Use client for development run");
    _ = STEP_client_dev(b, target, optimize, dev_client_step, raylib) catch |err| {
        std.log.err("build::STEP_client_dev: {any}", .{err});
        std.posix.exit(1);
    };

    const release_server_step = b.step("release-server", "Release build server");
    const server_targets: []const std.Target.Query = &.{
        .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu },
    };
    _ = STEP_release_server(b, server_targets, release_server_step) catch |err| {
        std.log.err("build::STEP_release_server: {any}", .{err});
        std.posix.exit(1);
    };
    const release_client_step = b.step("release-client", "Release build client");
    _ = STEP_release_client(b, target, optimize, release_client_step, raylib) catch |err| {
        std.log.err("build::STEP_release_client: {any}", .{err});
        std.posix.exit(1);
    };

    var server_unit_tests = addTestRunner(b, target, optimize, "src/server/main.zig");
    var aids_unit_tests = addTestRunner(b, target, optimize, "src/aids/aids.zig");

    const run_testing_server = b.step("testing-server", "Run unit tests for everything");
    _ = STEP_testing_server(b, target, optimize, run_testing_server) catch |err| {
        std.log.err("build::STEP_testing_server: {any}", .{err});
        std.posix.exit(1);
    };

    const whole_test_step = b.step("test", "Run unit tests for everything");
    whole_test_step.dependOn(&server_unit_tests.step);
    whole_test_step.dependOn(&aids_unit_tests.step);
}
