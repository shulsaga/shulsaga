const std = @import("std");
const vec3 = @import("vec3.zig");
const ray = @import("ray.zig");
const hittable = @import("hittable.zig");
const sphere = @import("sphere.zig");
const material = @import("material.zig");
const integrator = @import("integrator.zig");

const Color = vec3.Color;
const Point3 = vec3.Point3;
const Vec3 = vec3.Vec3;
const Ray = ray.Ray;
const HittableList = hittable.HittableList;
const Sphere = sphere.Sphere;
const Lambertian = material.Lambertian;
const Metal = material.Metal;
const Dielectric = material.Dielectric;
const Emission = material.Emission;
const Material = material.Material;
const DefaultPrng = std.Random.DefaultPrng;
const PathTracer = integrator.PathTracer;

pub fn main() !void {
    const aspect_ratio = 16.0 / 9.0;
    const image_width = 400;
    const image_height = @as(u32, @intFromFloat(@as(f32, @floatFromInt(image_width)) / aspect_ratio));
    const samples_per_pixel = 10;
    const max_depth = 10;

    // World
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var world = HittableList.init(allocator);
    defer world.deinit();

    var lambertian = Lambertian{ .albedo = Color.new(0.7, 0.3, 0.3) };
    var metal = Metal{ .albedo = Color.new(0.8, 0.8, 0.8), .fuzz = 0.1 };
    var glass = Dielectric{ .ir = 1.5 };
    var ground = Lambertian{ .albedo = Color.new(0.8, 0.8, 0.0) };
    var light = Emission{ .color = Color.new(4.0, 4.0, 4.0) };
    var s1 = Sphere{ .center = Point3.new(0, 0, -1), .radius = 0.5, .mat = lambertian.as_material() };
    var s2 = Sphere{ .center = Point3.new(1, 0, -1), .radius = 0.5, .mat = metal.as_material() };
    var s3 = Sphere{ .center = Point3.new(-1, 0, -1), .radius = 0.5, .mat = glass.as_material() };
    var s4 = Sphere{ .center = Point3.new(0, -100.5, -1), .radius = 100, .mat = ground.as_material() };
    var s5 = Sphere{ .center = Point3.new(0, 2, -1), .radius = 0.5, .mat = light.as_material() };
    try world.add(s1.as_hittable());
    try world.add(s2.as_hittable());
    try world.add(s3.as_hittable());
    try world.add(s4.as_hittable());
    try world.add(s5.as_hittable());

    // Camera
    const viewport_height = 2.0;
    const viewport_width = aspect_ratio * viewport_height;
    const focal_length = 1.0;

    const origin = Point3.new(0, 0, 0);
    const horizontal = Vec3.new(viewport_width, 0, 0);
    const vertical = Vec3.new(0, viewport_height, 0);
    const lower_left_corner = origin.sub(horizontal.div(2)).sub(vertical.div(2)).sub(Vec3.new(0, 0, focal_length));

    // Integrator
    var pt = PathTracer{};
    const integrator_inst = pt.as_integrator();

    // Render
    var file = try std.fs.cwd().createFile("image.ppm", .{});
    defer file.close();

    var writer = file.writer();

    try writer.print("P3\n{d} {d}\n255\n", .{ image_width, image_height });

    var prng = std.Random.DefaultPrng.init(0);

    var j: i32 = image_height - 1;
    while (j >= 0) : (j -= 1) {
        std.debug.print("\rScanlines remaining: {d}", .{j});
        var i: i32 = 0;
        while (i < image_width) : (i += 1) {
            var pixel_color = Color.new(0, 0, 0);
            var s: u32 = 0;
            while (s < samples_per_pixel) : (s += 1) {
                const u = (@as(f32, @floatFromInt(i)) + prng.random().float(f32)) / (image_width - 1);
                const v = (@as(f32, @floatFromInt(j)) + prng.random().float(f32)) / (image_height - 1);
                const r = Ray{
                    .origin = origin,
                    .direction = lower_left_corner.add(horizontal.mul(u)).add(vertical.mul(v)).sub(origin),
                };
                pixel_color = pixel_color.add(integrator_inst.render(&world, r, &prng, max_depth));
            }
            pixel_color = pixel_color.div(@as(f32, @floatFromInt(samples_per_pixel)));
            // Gamma correction
            const r = std.math.sqrt(pixel_color.x);
            const g = std.math.sqrt(pixel_color.y);
            const b = std.math.sqrt(pixel_color.z);
            const ir = @as(u8, @intFromFloat(255.999 * r));
            const ig = @as(u8, @intFromFloat(255.999 * g));
            const ib = @as(u8, @intFromFloat(255.999 * b));
            try writer.print("{d} {d} {d}\n", .{ ir, ig, ib });
        }
    }
    std.debug.print("\nDone.\n", .{});
}

fn ray_color(r: Ray, world: *const HittableList, prng: *DefaultPrng, depth: u32) Color {
    var rec: hittable.HitRecord = undefined;
    if (depth == 0) return Color.new(0, 0, 0);
    if (world.hit(r, 0.001, 1000, &rec)) {
        if (rec.mat) |mat_ptr| {
            const mat: *const Material = @alignCast(@ptrCast(mat_ptr));
            const emission = mat.emitted(&rec);
            var attenuation: Color = undefined;
            var scattered: Ray = undefined;
            if (mat.scatter(r, &rec, &attenuation, &scattered, prng)) {
                return emission.add(attenuation.mulv(ray_color(scattered, world, prng, depth - 1)));
            }
            return emission;
        }
    }
    const unit_direction = r.direction.unit_vector();
    const t = 0.5 * (unit_direction.y + 1.0);
    return Color.new(1.0, 1.0, 1.0).mul(1.0 - t).add(Color.new(0.5, 0.7, 1.0).mul(t));
}
