const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const lib = b.addStaticLibrary("zig_geojson", "src/main.zig");
    lib.setBuildMode(mode);
    lib.install();

    var main_tests = b.addTest("src/main.zig");
    main_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);

    const example_step = b.step("examples", "Build examples");
    inline for ([_][]const u8{"simple_feature"}) |example_name| {
        const example = b.addExecutable(example_name, "example/" ++ example_name ++ ".zig");
        example.addPackagePath("zig_geojson", "src/main.zig");
        example.setBuildMode(mode);
        example.install();
        example_step.dependOn(&example.step);
    }
}
