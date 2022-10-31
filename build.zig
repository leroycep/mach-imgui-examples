const std = @import("std");
const Pkg = std.build.Pkg;
const mach = @import("./lib/mach/build.zig");
const mach_imgui = @import("./lib/imgui/build.zig");

const mach_imgui_pkg = mach_imgui.getPkg(&[_]Pkg{mach.pkg});

pub fn build(b: *std.build.Builder) !void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    try buildCounter(b, target, mode);
    try buildTemperatureConverter(b, target, mode);
}

pub fn buildCounter(b: *std.build.Builder, target: std.zig.CrossTarget, mode: std.builtin.Mode) !void {
    const example_app = try mach.App.init(
        b,
        .{
            .name = "counter",
            .src = "./counter/main.zig",
            .target = target,
            .deps = &[_]Pkg{mach_imgui_pkg},
        },
    );

    example_app.setBuildMode(mode);
    try example_app.link(.{});
    try mach_imgui.link(example_app.step);

    const compile_step = b.step(b.fmt("compile-{s}", .{example_app.name}), b.fmt("Compile {s}", .{example_app.name}));
    compile_step.dependOn(&b.addInstallArtifact(example_app.step).step);
    b.getInstallStep().dependOn(compile_step);

    const run_cmd = try example_app.run();
    run_cmd.dependOn(compile_step);

    const test_step = b.step("test", "Test");
    test_step.dependOn(compile_step);

    const run_step = b.step(b.fmt("run-{s}", .{example_app.name}), b.fmt("Run {s}", .{example_app.name}));
    run_step.dependOn(run_cmd);
}

pub fn buildTemperatureConverter(b: *std.build.Builder, target: std.zig.CrossTarget, mode: std.builtin.Mode) !void {
    const example_app = try mach.App.init(
        b,
        .{
            .name = "temperature-converter",
            .src = "./02-temperature-converter/main.zig",
            .target = target,
            .deps = &[_]Pkg{mach_imgui_pkg},
        },
    );

    example_app.setBuildMode(mode);
    try example_app.link(.{});
    try mach_imgui.link(example_app.step);

    const compile_step = b.step(b.fmt("compile-{s}", .{example_app.name}), b.fmt("Compile {s}", .{example_app.name}));
    compile_step.dependOn(&b.addInstallArtifact(example_app.step).step);
    b.getInstallStep().dependOn(compile_step);

    const run_cmd = try example_app.run();
    run_cmd.dependOn(compile_step);

    const test_step = b.step("test", "Test");
    test_step.dependOn(compile_step);

    const run_step = b.step(b.fmt("run-{s}", .{example_app.name}), b.fmt("Run {s}", .{example_app.name}));
    run_step.dependOn(run_cmd);
}

inline fn thisDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse ".";
}
