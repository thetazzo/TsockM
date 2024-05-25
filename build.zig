const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const server_exe = b.addExecutable(.{
        .name = "tsockm-server",
        .root_source_file = b.path("src/server/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(server_exe);

    const client_exe = b.addExecutable(.{
        .name = "tsockm-client",
        .root_source_file = b.path("src/client/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(client_exe);
}
