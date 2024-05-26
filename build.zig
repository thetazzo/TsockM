const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const common_mod = b.addModule("cmn", .{
        .root_source_file = b.path("src/lib/common.zig"),
    });
    const protocol_mod = b.addModule("ptc", .{
        .root_source_file = b.path("src/lib/protocol.zig"),
    });

    const server_exe = b.addExecutable(.{
        .name = "tsockm-server",
        .root_source_file = b.path("src/server/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    server_exe.root_module.addImport("ptc", protocol_mod);
    server_exe.root_module.addImport("cmn", common_mod);

    b.installArtifact(server_exe);
    const run_server_exe = b.addRunArtifact(server_exe);

    const run_server_step = b.step("server", "Run the SERVER");
    run_server_step.dependOn(&run_server_exe.step);

    const client_exe = b.addExecutable(.{
        .name = "tsockm-client",
        .root_source_file = b.path("src/client/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    client_exe.root_module.addImport("ptc", protocol_mod);
    client_exe.root_module.addImport("cmn", common_mod);

    b.installArtifact(client_exe);
    const run_client_exe = b.addRunArtifact(client_exe);

    const run_client_step = b.step("client", "Run the CLIENT");
    run_client_step.dependOn(&run_client_exe.step);
}
