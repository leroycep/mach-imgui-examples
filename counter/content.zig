const std = @import("std");
const mach = @import("mach");
const zgui = @import("mach-imgui");

pub const Content = struct {
    counter: u32,
};

pub fn render_content(core: *mach.Core, content: *Content) !void {
    const window_size = core.getWindowSize();
    zgui.backend.newFrame(
        core,
        window_size.width,
        window_size.height,
    );

    if (!zgui.begin("Demo Settings", .{})) {
        zgui.end();
        return;
    }
    defer zgui.end();

    zgui.text("{}", .{content.counter});
    if (zgui.button("Count", .{})) {
        content.counter += 1;
    }
}
