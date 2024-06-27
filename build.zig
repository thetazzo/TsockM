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
    return .{
        .module = mod,
    };
}

fn Sqids(b: *std.Build) struct { module: *std.Build.Module } {
    const sqids_dep = b.dependency("sqids", .{});
    const mod = sqids_dep.module("sqids");
    return .{
        .module = mod,
    };
}

const MAD = struct {
    module: *std.Build.Module,
    artifact: *std.Build.Step.Compile,
    dependency: *std.Build.Dependency,
    LDB: rlz.LinuxDisplayBackend,
};
fn Raylib(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, ldb: rlz.LinuxDisplayBackend) MAD {
    const raylib_dep = b.dependency("raylib-zig", .{
        .target = target,
        .optimize = optimize,
        .linux_display_backend = ldb,
    });

    const raylib = raylib_dep.module("raylib");
    const raylib_artifact = raylib_dep.artifact("raylib");

    //web exports are completely separate
    if (target.query.os_tag == .emscripten) {
        const exe_lib = rlz.emcc.compileForEmscripten(b, "tsockm-client", "src/client/main.zig", target, optimize);

        exe_lib.linkLibrary(raylib_artifact);
        exe_lib.root_module.addImport("raylib", raylib);

        // Note that raylib itself is not actually added to the exe_lib output file, so it also needs to be linked with emscripten.
        const link_step = rlz.emcc.linkWithEmscripten(b, &[_]*std.Build.Step.Compile{ exe_lib, raylib_artifact }) catch |err| {
            std.log.err("41::Raylib: {any}", .{err});
            std.posix.exit(1);
        };

        b.getInstallStep().dependOn(&link_step.step);
        const run_step = rlz.emcc.emscriptenRunStep(b) catch |err| {
            std.log.err("47::Raylib: {any}", .{err});
            std.posix.exit(1);
        };
        run_step.step.dependOn(&link_step.step);
        const run_option = b.step("run", "Run nnp");
        run_option.dependOn(&run_step.step);
        return .{
            .module = raylib,
            .dependency = raylib_dep,
            .artifact = raylib_artifact,
            .LDB = ldb,
        };
    }

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
    const sqids = Sqids(b);

    const server_program = Program(b, .{ .name = "tsockm-server", .root_source_file = b.path("./src/server/main.zig"), .target = target, .optimize = optimize });
    server_program.module.addImport("sqids", sqids.module);

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
}

fn STEP_client_dev(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, step: *std.Build.Step, raylib: MAD) !void {
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
}

fn STEP_release_server(b: *std.Build, targets: []const std.Target.Query, step: *std.Build.Step) !void {
    const sqids = Sqids(b);

    for (targets) |t| {
        const target = b.resolveTargetQuery(t);
        const server = Program(b, .{
            .name = "tsockm-server",
            .root_source_file = b.path("./src/server/main.zig"),
            .target = target,
            .optimize = .ReleaseSafe,
        });
        server.module.addImport("sqids", sqids.module);
        const target_tripple = try target.result.linuxTriple(b.allocator);
        const out_dir_path = try std.fmt.allocPrint(b.allocator, "tsockm-server-{s}-{s}", .{ server_version, target_tripple });
        const client_install = b.addInstallArtifact(server.exe, .{
            .dest_dir = .{
                .override = .{
                    .custom = out_dir_path,
                },
            },
        });
        step.dependOn(&client_install.step);
    }
}

fn STEP_release_client(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, step: *std.Build.Step, raylib: MAD) !void {
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

    const target_tripple = try target.result.linuxTriple(b.allocator);
    const out_dir_path = try std.fmt.allocPrint(b.allocator, "tsockm-client-{s}-{s}-{s}", .{ client_version, target_tripple, @tagName(raylib.LDB) });
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
    const cpa = b.addSystemCommand(&.{ "cp", "-r", "src/assets/fonts", full_out_path });
    cpa.step.name = "copy font assets";
    cpa.step.dependOn(&client_install.step);
    step.dependOn(&cpa.step);
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
    const server_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/server/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    server_unit_tests.root_module.addImport("aids", Aids(b).module);
    server_unit_tests.root_module.addImport("sqids", Sqids(b).module);
    const run_server_unit_test = b.addRunArtifact(server_unit_tests);
    const server_test_step = b.step("test-server", "Run unit tests for the server");
    server_test_step.dependOn(&run_server_unit_test.step);
    const aids_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/aids/aids.zig"),
        .target = target,
        .optimize = optimize,
    });
    aids_unit_tests.root_module.addImport("aids", Aids(b).module);
    const run_aids_unit_test = b.addRunArtifact(aids_unit_tests);
    const aids_test_step = b.step("test-aids", "Run unit tests for the aids");
    aids_test_step.dependOn(&run_aids_unit_test.step);

    const server_program = Program(b, .{ .name = "testing-server", .root_source_file = b.path("./src/server/tester-main.zig"), .target = target, .optimize = optimize });
    server_program.exe.root_module.addImport("sqids", Sqids(b).module);
    const server_artifact = b.addInstallArtifact(server_program.exe, .{});
    const run_server_artifact = b.addRunArtifact(server_program.exe);

    const whole_test_step = b.step("test", "Run unit tests for everything");
    whole_test_step.dependOn(&run_server_unit_test.step);
    whole_test_step.dependOn(&run_aids_unit_test.step);

    const run_test_server = b.step("run-test-server", "Run unit tests for everything");
    run_test_server.dependOn(&server_artifact.step);
    run_test_server.dependOn(&run_server_artifact.step);
}
