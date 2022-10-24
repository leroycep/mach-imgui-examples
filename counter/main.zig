const std = @import("std");
const mach = @import("mach");
const mach_imgui = @import("mach-imgui");
const gpu = @import("gpu");

const content = @import("./content.zig");

pub const App = @This();

pipeline: *gpu.RenderPipeline,
queue: *gpu.Queue,
content: content.Content,
refresh_counter: u32 = 0,

fn create_vertex_state(vs_module: *gpu.ShaderModule) gpu.VertexState {
    return gpu.VertexState{
        .module = vs_module,
        .entry_point = "vertex",
    };
}

fn create_fragment_state(fs_module: *gpu.ShaderModule, targets: []const gpu.ColorTargetState) gpu.FragmentState {
    return gpu.FragmentState.init(.{
        .module = fs_module,
        .entry_point = "fragment",
        .targets = targets,
    });
}

fn create_color_target_state(swap_chain_format: gpu.Texture.Format) gpu.ColorTargetState {
    const blend = gpu.BlendState{};
    const color_target = gpu.ColorTargetState{
        .format = swap_chain_format,
        .blend = &blend,
        .write_mask = gpu.ColorWriteMaskFlags.all,
    };

    return color_target;
}

pub fn init(app: *App, core: *mach.Core) !void {
    std.debug.print("backend type: {?}\n", .{core.backend_type});
    std.debug.print("\n", .{});

    try core.setOptions(mach.Options{
        .title = "Imgui in mach",
        .width = 1000,
        .height = 800,
        .vsync = .none,
    });

    mach_imgui.init();

    const scale_factor = 1;
    const font_size = 26.0 * scale_factor;
    const font_normal = mach_imgui.io.addFontFromFile("resources/Roboto-Medium.ttf", font_size);

    const triangle_module = core.device.createShaderModuleWGSL("triangle.wgsl", @embedFile("./triangle.wgsl"));
    defer triangle_module.release();

    const color_target = create_color_target_state(core.swap_chain_format);

    const pipeline_descriptor = gpu.RenderPipeline.Descriptor{
        .fragment = &create_fragment_state(triangle_module, &.{color_target}),
        .vertex = create_vertex_state(triangle_module),
    };

    mach_imgui.backend.init(core.device, @enumToInt(core.swap_chain_format));
    mach_imgui.io.setDefaultFont(font_normal);

    const style = mach_imgui.getStyle();
    style.window_min_size = .{ 100.0, 100.0 };
    style.window_border_size = 8.0;
    style.scrollbar_size = 6.0;
    style.scaleAllSizes(scale_factor);

    app.* = .{
        .pipeline = core.device.createRenderPipeline(&pipeline_descriptor),
        .queue = core.device.getQueue(),
        .content = .{ .counter = 0 },
    };
}

pub fn deinit(_: *App, _: *mach.Core) void {
    mach_imgui.backend.deinit();
}

pub fn update(app: *App, core: *mach.Core) !void {
    if (core.hasEvent()) {
        const input_event: mach.Event = core.pollEvent().?;
        mach_imgui.backend.passEvent(input_event);
        app.refresh_counter = 2;
    }

    if (app.refresh_counter > 0) {
        core.setWaitEvent(0.0);
    } else {
        core.setWaitEvent(std.math.inf(f64));
    }
    app.refresh_counter -|= 1;

    const back_buffer_view = core.swap_chain.?.getCurrentTextureView();
    const color_attachment = gpu.RenderPassColorAttachment{
        .view = back_buffer_view,
        .clear_value = gpu.Color{ .r = 0.1, .g = 0.1, .b = 0.1, .a = 1.0 },
        .load_op = .clear,
        .store_op = .store,
    };

    const encoder = core.device.createCommandEncoder(null);
    const render_pass_info = gpu.RenderPassDescriptor.init(.{
        .color_attachments = &.{color_attachment},
    });
    const pass = encoder.beginRenderPass(&render_pass_info);
    pass.setPipeline(app.pipeline);
    pass.draw(3, 1, 0, 0);

    try content.render_content(core, &app.content);

    mach_imgui.backend.draw(pass);

    pass.end();
    pass.release();

    var command = encoder.finish(null);
    encoder.release();

    app.queue.submit(&.{command});
    command.release();

    core.swap_chain.?.present();
    back_buffer_view.release();
}
