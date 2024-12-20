const std = @import("std");
const Build = std.Build;
const CompileStep = std.Build.Step.Compile;

/// set this to true to link libc
const should_link_libc = false;

const required_zig_version = std.SemanticVersion.parse("0.13.0") catch unreachable;

fn linkObject(b: *Build, obj: *CompileStep) void {
    if (should_link_libc) obj.linkLibC();
    _ = b;

    // Add linking for packages or third party libraries here
}

pub fn build(b: *Build) void {
    if (comptime @import("builtin").zig_version.order(required_zig_version) == .lt) {
        std.debug.print("Warning: Your version of Zig too old. You will need to download a newer build\n", .{});
        std.os.exit(1);
    }

    const target = b.standardTargetOptions(.{});
    const mode = b.standardOptimizeOption(.{});

    const install_all = b.step("install_all", "Install all days");
    const run_all = b.step("run_all", "Run all days");

    const generate = b.step("generate", "Generate stub files from template/template.zig");
    const build_generate = b.addExecutable(.{
        .name = "generate",
        .root_source_file = b.path("template/generate.zig"),
        .target = target,
        .optimize = .ReleaseSafe,
    });
    var opts = b.addOptions();
    const end_day = b.option(
        u32,
        "day",
        "Generate a specific day",
    );
    opts.addOption(
        u32,
        "end_day",
        end_day orelse 25,
    );
    opts.addOption(
        u32,
        "start_day",
        end_day orelse 1,
    );
    build_generate.root_module.addOptions("config", opts);

    const run_generate = b.addRunArtifact(build_generate);
    run_generate.setCwd(b.path("")); // This could probably be done in a more idiomatic way
    generate.dependOn(&run_generate.step);

    const install_generate = b.addInstallArtifact(build_generate, .{});
    const install_generate_step = b.step("install_generate", "Install generate.exe");
    install_generate_step.dependOn(&install_generate.step);

    // Set up an exe for each day
    var day: u32 = 1;
    while (day <= 25) : (day += 1) {
        const dayString = b.fmt("day{:0>2}", .{day});
        const zigFile = b.fmt("src/{s}.zig", .{dayString});

        const exe = b.addExecutable(.{
            .name = dayString,
            .root_source_file = b.path(zigFile),
            .target = target,
            .optimize = mode,
        });
        linkObject(b, exe);

        const install_cmd = b.addInstallArtifact(exe, .{});

        const build_test = b.addTest(.{
            .root_source_file = b.path(zigFile),
            .target = target,
            .optimize = mode,
        });
        linkObject(b, build_test);

        const run_test = b.addRunArtifact(build_test);

        {
            const step_key = b.fmt("install_{s}", .{dayString});
            const step_desc = b.fmt("Install {s}.exe", .{dayString});
            const install_step = b.step(step_key, step_desc);
            install_step.dependOn(&install_cmd.step);
            install_all.dependOn(&install_cmd.step);
        }

        {
            const step_key = b.fmt("test_{s}", .{dayString});
            const step_desc = b.fmt("Run tests in {s}", .{zigFile});
            const step = b.step(step_key, step_desc);
            step.dependOn(&run_test.step);
        }

        const run_cmd = b.addRunArtifact(exe);
        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const run_desc = b.fmt("Run {s}", .{dayString});
        const run_step = b.step(dayString, run_desc);
        run_step.dependOn(&run_cmd.step);
        run_all.dependOn(&run_cmd.step);
    }

    const exe_check = b.addExecutable(.{
        .name = "check",
        .root_source_file = b.path("src/check.zig"),
        .target = target,
        .optimize = mode,
    });

    const check = b.step("check", "Run all days");
    check.dependOn(&exe_check.step);

    const run_check = b.step("run_check", "Run check");
    const run_check_cmd = b.addRunArtifact(exe_check);
    run_check.dependOn(&run_check_cmd.step);

    // Set up tests for util.zig
    {
        const test_util = b.step("test_util", "Run tests in util.zig");
        const test_cmd = b.addTest(.{
            .root_source_file = b.path("src/util.zig"),
            .target = target,
            .optimize = mode,
        });
        linkObject(b, test_cmd);
        test_util.dependOn(&test_cmd.step);
    }

    // Set up all tests contained in test_all.zig
    const test_all = b.step("test", "Run all tests");
    const all_tests = b.addTest(.{
        .root_source_file = b.path("src/test_all.zig"),
        .target = target,
        .optimize = mode,
    });
    const run_all_tests = b.addRunArtifact(all_tests);
    test_all.dependOn(&run_all_tests.step);
}
