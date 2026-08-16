# CONTEXT

Domain glossary for godot-wild-96. Terms here are the canonical language; code and docs should use them.

## Core concepts

- **Dash**: The player ability that moves the character along a fixed direction at `dash_speed` for a computed duration (`dash duration`).
- **Dash direction**: The normalized movement direction of a dash.
- **Dash band**: The strip of destructible terrain within `bite_radius` of the dash line. This is the exact region a dash removes.
- **Exit point** (formerly "exit wound"): The point where the backwards raycast first hits the far side of destructible terrain along the dash line.
- **Dash distance**: The distance from the player's position at dash start to the exit point. Formerly "dynamic distance".
- **Dash duration**: The time the dash lasts, computed as `dash distance / dash speed`.
- **Destructible terrain**: A terrain chunk managed by `DestructiblePolygon2D` that can be carved.
- **Carve** (verb; code name `destruct`): Remove a polygonal region (the dash band mask) from a terrain chunk, updating both its mesh and its collision.
- **Wipe**: The GPU-side visual effect that progressively erases the dash band from view over the dash duration, so the tunnel appears to grow as the player passes.
- **Terrain layer**: The collision layer assigned to destructible terrain. Today it is layer 1 (code) but the design target is a dedicated layer.
