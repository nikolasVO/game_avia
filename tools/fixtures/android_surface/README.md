# Isolated Android surface diagnostic

Same pinned Godot4.7.2 Compatibility renderer,30FPS/30Hz. No game, network, assets, profile or plugins. A moving2D circle and frame/draw/physics counters isolate lifecycle problems from flight/network loops. Set `user://surface.cfg` to `[test] mode="3d"` (on separate lines) to add a rotating lit cube.

Use a separate diagnostic application ID, never production data. Wait for a `surface_frame` with `draws=0` for the cold Home/resume race; allow up to120s for emulator shader compilation and assess continued draw progress after that. For warmed cycles wait for at least30 actual draws first. Filter logcat by this process PID; an old fixture may still emit the same event names. Capture screenshots and lifecycle notifications. A resumed Activity alone does not prove rendering. No fixture result proves gameplay or physical-phone FPS.
