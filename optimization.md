# optimization.md

## The Problem
Doing real-time polygon clipping (`Geometry2D.clip_polygons`) and modifying physics collision shapes (`StaticBody2D`) every frame is death for web builds (Wasm) on low-end hardware. 
- Rebuilding the physics BVH tree constantly tanks FPS.
- Creating and freeing nodes every tick triggers heavy GC pauses.
- Pure GDScript math can't keep up under tight frame budgets.

## The Prod Solution: Raster over Vectors
Stop fighting the physics engine. Separate visuals from physics entirely.

1. **Visuals (GPU):** Use an alpha mask or shader subtraction. Let the GPU handle the tunnel rendering for free.
2. **Logic/Caliper (CPU):** Keep an in-memory `Image` buffer. Use fast O(1) pixel lookups (`Image.get_pixel()`) as your "caliper" instead of heavy raycasts against changing geometry.
3. **Physics (Deferred):** Turn off terrain collisions *during* the dash. Only run the expensive bitmap-to-polygon conversion (`BitMap.opaque_to_polygons`) **once** when the dash ends.
4. **The Nuclear Option (Rust):** If WebAssembly still chokes on the bitmap manipulation, port the pixel checks and grid management to a Rust GDExtension (`gdext`).
