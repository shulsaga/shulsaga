const std = @import("std");
const Random = std.Random;
const ray_mod = @import("ray.zig");
const hittable = @import("hittable.zig");
const material = @import("material.zig");

const Ray = ray_mod.Ray;
const HittableList = hittable.HittableList;
const Material = material.Material;
const DefaultPrng = Random.DefaultPrng;

pub const Integrator = struct {
    render_fn: *const fn(self: *const anyopaque, world: *const HittableList, r: Ray, rng: *DefaultPrng, depth: u32) @import("vec3.zig").Color,
    data: *const anyopaque,

    pub fn render(self: Integrator, world: *const HittableList, r: Ray, rng: *DefaultPrng, depth: u32) @import("vec3.zig").Color {
        return self.render_fn(self.data, world, r, rng, depth);
    }
};

pub const PathTracer = struct {
    pub fn render(self: *const PathTracer, world: *const HittableList, r: Ray, rng: *DefaultPrng, depth: u32) @import("vec3.zig").Color {
        var rec: hittable.HitRecord = undefined;
        if (depth == 0) return @import("vec3.zig").Color.new(0, 0, 0);
        if (world.hit(r, 0.001, 1000, &rec)) {
            var attenuation: @import("vec3.zig").Color = undefined;
            var scattered: Ray = undefined;
            const mat: *const Material = @alignCast(@ptrCast(rec.mat));
            if (mat.scatter(r, &rec, &attenuation, &scattered, rng)) {
                return attenuation.mulv(self.render(world, scattered, rng, depth - 1));
            }
            return @import("vec3.zig").Color.new(0, 0, 0);
        }
        const unit_direction = r.direction.unit_vector();
        const t = 0.5 * (unit_direction.y + 1.0);
        return @import("vec3.zig").Color.new(1.0, 1.0, 1.0).mul(1.0 - t).add(@import("vec3.zig").Color.new(0.5, 0.7, 1.0).mul(t));
    }
    pub fn as_integrator(self: *const PathTracer) Integrator {
        return .{
            .data = self,
            .render_fn = struct {
                fn render_wrapper(self_ptr: *const anyopaque, world: *const HittableList, r: Ray, rng: *DefaultPrng, depth: u32) @import("vec3.zig").Color {
                    const pt: *const PathTracer = @alignCast(@ptrCast(self_ptr));
                    return pt.render(world, r, rng, depth);
                }
            }.render_wrapper,
        };
    }
};
