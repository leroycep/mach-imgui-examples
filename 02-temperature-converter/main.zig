const std = @import("std");
const mach = @import("mach");
const mach_imgui = @import("mach-imgui");
const gpu = @import("gpu");

pub const App = @This();

queue: *gpu.Queue,
content: Content,
refresh_counter: u32 = 0,

pub fn init(app: *App, core: *mach.Core) !void {
    try core.setOptions(mach.Options{
        .title = "Temperature Converter",
        .width = 1000,
        .height = 800,
        .vsync = .none,
    });

    mach_imgui.init();

    const scale_factor = 1;
    const font_size = 26.0 * scale_factor;
    const font_normal = mach_imgui.io.addFontFromFile("resources/Roboto-Medium.ttf", font_size);

    mach_imgui.backend.init(core.device, @enumToInt(core.swap_chain_format));
    mach_imgui.io.setDefaultFont(font_normal);

    app.* = .{
        .queue = core.device.getQueue(),
        .content = .{},
    };
}

pub fn deinit(_: *App, _: *mach.Core) void {
    mach_imgui.backend.deinit();
}

pub const Content = struct {
    // The temperature in kelvin
    temperature_kelvin: f32 = 273,

    pub fn render(this: *@This(), core: *mach.Core) !void {
        const im = mach_imgui;

        const window_size = core.getWindowSize();
        im.backend.newFrame(
            core,
            window_size.width,
            window_size.height,
        );

        if (!im.begin("Temperature Converter", .{})) {
            im.end();
            return;
        }
        defer im.end();

        var fahrenheit = kelvinToFahrenheit(this.temperature_kelvin);
        if (im.dragFloat("Fahrenheit", .{ .v = &fahrenheit })) {
            this.temperature_kelvin = fahrenheitToKelvin(fahrenheit);
        }
    }

    fn kelvinToFahrenheit(kelvin: f32) f32 {
        return 1.8 * (kelvin - 273) + 32;
    }

    fn fahrenheitToKelvin(fahrenheit: f32) f32 {
        return ((fahrenheit - 32) / 1.8) + 273;
    }
};

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

    try app.content.render(core);

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
