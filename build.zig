const std = @import("std");

pub fn build(b: *std.Build) void {

    const sqids_dep = b.dependency("sqids", .{});

    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const common_mod = b.addModule("cmn", .{
        .root_source_file = b.path("src/lib/common.zig"),
    });
    const protocol_mod = b.addModule("ptc", .{
        .root_source_file = b.path("src/lib/protocol.zig"),
    });
    const text_clr_mod = b.addModule("text_color", .{
        .root_source_file = b.path("src/lib/text_color.zig"),
    });
    const sqids_mod = sqids_dep.module("sqids");

    const server_exe = b.addExecutable(.{
        .name = "tsockm-server",
        .root_source_file = b.path("src/server/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    server_exe.root_module.addImport("ptc", protocol_mod);
    server_exe.root_module.addImport("cmn", common_mod);
    server_exe.root_module.addImport("text_color", text_clr_mod);
    server_exe.root_module.addImport("sqids", sqids_mod);

    b.installArtifact(server_exe);
    const run_server_exe = b.addRunArtifact(server_exe);

    const run_server_step = b.step("server", "Run the SERVER");
    // add command line arguments
    if (b.args) |args| {
        run_server_exe.addArgs(args);
    }
    run_server_step.dependOn(&run_server_exe.step);

    const linux_target = .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu };
    const client_exe = b.addExecutable(.{
        .name = "tsockm-client",
        .root_source_file = b.path("src/client/main.zig"),
        .target = b.resolveTargetQuery(linux_target),
        .strip = true,
        .optimize = optimize,
    });
    client_exe.root_module.addImport("ptc", protocol_mod);
    client_exe.root_module.addImport("cmn", common_mod);
    client_exe.root_module.addImport("text_color", text_clr_mod);

    b.installArtifact(client_exe);
    const run_client_exe = b.addRunArtifact(client_exe);
    // add command line arguments
    if (b.args) |args| {
        run_client_exe.addArgs(args);
    }
    const run_client_step = b.step("client", "Run the CLIENT");
    run_client_step.dependOn(&run_client_exe.step);
}
