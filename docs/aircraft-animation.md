# Fighter landing-gear animation

The six selectable fighter candidates now use three independently pivoted landing-gear legs. The existing replicated gear flag sets the target; client rendering moves toward it at a constant travel rate. The nose folds aft and the main legs inward. Repeated snapshots preserve travel, reversing the flag reverses movement, and a first airborne snapshot initializes the retracted baseline. The existing original aircraft remain unchanged.

`visual.gear_retract_seconds` in each fighter configuration sets the authored animation duration (0.85–1.25 seconds). These are arcade visual timings, not real aircraft specifications. Simulation, gear-down landing validation and protocol 4 remain as before. Rendering does not confer collision authority on the visual struts.

Three instances share one 24-triangle strut/wheel mesh and the existing vertex material: 72 gear triangles and one instanced surface, matching the previous combined gear budget. The assembly disappears beyond 500 m and when fully retracted. Stable endpoints do not upload transforms each frame. The Su-35 nozzle cue and afterburner remain intact.

Godot 4.7.2 desktop compatibility rendering passed 60 real-node checks and 36 captures across six candidates and three gear states. The headless Dummy renderer does not return actual MultiMesh transforms; the systems runner requires a renderer. Shared simulation, geometry and six circuit suites also passed. A separate ENet/DTLS server and two rendered Su-35S/Gripen clients verified local and remote travel, endpoints and instance transforms over real snapshots. The first network attempt failed because the test environment omitted the existing private DTLS key path; the corrected environment passed. No deployment changed.

Evidence: [render checks](evidence/aircraft-gear-render.json), [network checks](evidence/aircraft-gear-network.json), [regressions and budgets](evidence/aircraft-gear-regressions.json), [front-quarter views](evidence/aircraft-gear-view-0.png), [side views](evidence/aircraft-gear-view-1.png).

Reproduce with `tools/aircraft_systems_check.py --godot PATH --out NEW_DIRECTORY`. Use `tools/game_check.py --render --systems-cycle --gear-audit --authority-audit --planes 6,8 --seconds 12 --godot PATH --out DIRECTORY` with the existing protected `AVIA_DTLS_KEY` path. Neither test is human control or physical-device acceptance.

The gear assembly is stylized authored geometry around candidate bodies. Correct type-specific bays, doors, wheel/strut shapes, other moving control surfaces, full aircraft recognition, mobile performance and physical controls remain open. This milestone does not accept any aircraft or the full P0–P6 task.
