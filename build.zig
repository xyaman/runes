const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addModule("runes", .{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // -- dependencies
    const mibu_dep = b.dependency("mibu", .{});
    lib.addImport("mibu", mibu_dep.module("mibu"));

    // -- tests
    const test_step = b.step("test", "Run all tests.");
    const tests = b.addTest(.{ .root_module = lib });
    const run_tests = b.addRunArtifact(tests);
    test_step.dependOn(&run_tests.step);

    // -- examples
    const examples = [_][]const u8{
        "0_simplelist",
        "1_todolist",
        "1_fancylist",
    };
    for (examples) |name| {
        const example_exe = b.addExecutable(.{
            .name = name,
            .root_module = b.createModule(.{
                .root_source_file = b.path(b.fmt("examples/{s}.zig", .{name})),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "runes", .module = lib },
                },
            }),
        });
        const run_example = b.addRunArtifact(example_exe);
        const example_step = b.step(name, b.fmt("Run {s} example", .{name}));
        example_step.dependOn(&run_example.step);
    }
}
