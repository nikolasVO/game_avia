# TRELLIS live asset validation — 17 November 2026

Asset branch: `task/trellis-live-validation-20261117`, based on `1f0dd2d435ebbd1dfef2ff56fc70512a4794dec2`. No merge to main, no game/client, multiplayer/server, Android or shared scene changes. Worker deployment is isolated at `/srv/game-avia/trellis-validation-20261117`; the running coordinator still uses its original repository. No service restart, new paid API call, weight download, gate bypass or environment/driver installation was performed.

The receipt required by the owner is outside Git at `/Users/nik/.codex/tmp/game-avia-trellis-validation-20261117/receipt.json`.

The first live job is `59adab633cd7`, asset `trellis_validation_smoke_20261117`. It uses the existing unchanged 1254×1254 `assets/source/reference-smoke.png`, SHA-256 `8720294d2190609e97e19302118df8e391a4dfcaf057ae98604d26ac0873106a`. The reference came from the prior paid OpenLux image smoke; its provider terms and unresolved requested-size mismatch remain as recorded in the original source manifest. This session made no paid call. This cube validates plumbing and is not an aircraft.

The second job is `7824ba0645c5`, asset `trellis_validation_plane_20261117`. Its reference is a project-authored procedural aircraft rendered with CPU Blender by `workers/assets/plane_reference.py`. The reference geometry and render are offered under CC0-1.0; that assertion applies to those authored reference files only. It is not an image API result and does not close the paid-image aircraft production requirement.

Source/model hashes, installed package versions, raw mesh snapshot hashes and final resource measurements are recorded in `reports/trellis_validation_20261117/installed-evidence.json`. The compact configuration loads six generator/decoder components, the approved local DINOv3 and MIT BiRefNet, offline. The inspected BiRefNet custom code is pinned by the existing model manifest: its local `config.json` disables backbone pretraining; its two Python sources and all selected weights are hashed in the evidence. No model files or protected credentials are in Git. The child has a per-artifact HOME, an environment allowlist, offline flags, nice 10 and two CPU threads.

Component licensing is not a blanket CC0 assertion for generated meshes. [TRELLIS.2 weights declare MIT](https://huggingface.co/microsoft/TRELLIS.2-4B/blob/af44b45f2e35a493886929c6d786e563ec68364d/README.md); [BiRefNet declares MIT](https://huggingface.co/ZhengPeng7/BiRefNet); [DINOv3 has its own license](https://github.com/facebookresearch/dinov3/blob/main/LICENSE.md), including use and redistribution conditions. The owner's access approval and instruction to use the existing token preceded this work. This run did not accept new account terms. Output commercial/publication clearance is not established by a successful technical test.

## Reproduction and ownership

Create a new unique asset ID/spec only for an intentional new generation. Repeating a validation key returns the same Store task and does not start a second process. Tasks are created and moved out of the executor queue in one transaction with their event/outbox entry. The external validator heartbeats its task; each process renews the single GPU lease and checks task ownership. Unknown tool outcomes remain blocked until files, hashes and process state are reconciled. Never delete an operation row just to rerun it.

```sh
cd /srv/game-avia/trellis-validation-20261117
PYTHONPATH=$PWD:/srv/game-avia/repo /srv/game-avia/venvs/core/bin/python3.12 \
  -m workers.assets.validate --repo "$PWD" \
  --key trellis_validation_plane_20261117 \
  --spec trellis_validation_20261117/plane-spec.json
```

The underlying GPU command is `/srv/game-avia/venvs/trellis/bin/python /srv/game-avia/trellis-validation-20261117/scripts/trellis_generate.py --request /srv/game-avia/artifacts/<asset_id>/generation.json --models /srv/game-avia/models/trellis512 --output /srv/game-avia/artifacts/<asset_id>/original.glb`. No credential is needed in the offline child. The original GLB embeds PNG textures rather than relying on the optional WebP extension. A raw CPU mesh snapshot is preserved on Thunder, separately from the optimized GLB.

The Blender command uses `--background --factory-startup --threads 2 --python scripts/blender_optimize.py -- --input <original.glb> --output-dir <artifact-dir> --manifest-name blender-manifest.json --triangles <budget> --texture-size 1024 --dimensions <X Z Y>`. The input remains intact. Geometry metadata is staged as `geometry-manifest.json`; the final `manifest.json` is atomically replaced only after isolated Godot validation. The initial smoke began before the staging change was loaded; its first geometry manifest was reconciled and its final manifest replaced after the actual Godot pass. Future runs use staged publication.

```sh
python3 -m workers.assets.godot_validate \
  --artifact-dir assets/catalog/trellis_validation_plane_20261117 \
  --godot /path/to/Godot --dimensions 10 2.8 8 --render
```

This creates an isolated temporary project, runs the real editor import, instantiates the imported scene, measures LOD0 bounds/pivot/materials/triangles and renders a preview with Compatibility. It does not edit the game project. Non-LOD0 meshes are hidden for that preview. The bundled `optimized.glb` includes all LODs and a box metadata mesh; a game must explicitly select a LOD and bind an actual physics collider. Separate `lod0.glb`, `lod1.glb`, `lod2.glb` files avoid displaying all LODs together.

## Remaining scope

A successful isolated import is not a playable integration, mobile performance measurement, aircraft animation setup, or version 0.1 acceptance. Aircraft silhouette, orientation, symmetry and thickness need their measured/visual outcomes below; no production acceptance is inferred from triangle budgets. Keep the cube as a technical artifact. The single game integrator decides when and how to import the plane candidate. No automatic merge is requested.

## Verified results

| Check | Status | Actual evidence |
|---|---|---|
| Real cube inference | PASS | 214.876 s load + inference; 1,710,768 vertices / 3,561,294 faces; peak allocated 3,343,810,048 bytes, reserved 3,810,525,184 bytes |
| Real original aircraft inference | PASS | 283.113 s load + inference; 262,926 vertices / 530,364 faces; peak allocated 2,815,540,224 bytes, reserved 2,862,612,480 bytes |
| Plane optimized geometry | PASS | LOD 19,400 / 6,000 / 1,500; one material, one UV set, two 1024² texture images, zero degenerate triangles, finite vertices/normals |
| Plane isolated Godot import/render | PASS | Real Mac Compatibility/OpenGL on AMD Radeon Pro 560X; orbit, top, front and side PNGs; measured about 10.002 × 2.801 × 8.002 m, bottom-center pivot |
| Plane canonical orientation | PASS | Top view exposed initial nose -X. Postprocess correction maps it to -Z, wings across X. Original inference/GLB untouched; both earlier postprocess snapshots retained on Thunder |
| Plane exact symmetry | FAIL | Approximate only: mean mirrored-nearest-vertex error 0.02972 m, max 0.36892 m, mean 0.297% of span. A recognizable full silhouette is visible, but strict perfect symmetry is not claimed |
| Cache on real final plane files | PASS | Same task/spec/artifacts returned `verified`; tool-operation count unchanged; no new inference |
| Tests | PASS | 18 tests: 17 asset/store unit checks and one installed Blender integration that executes fixture/import/rotation. Final cache compatibility amendment reran all 17 unit/store checks |
| Resource preservation | PASS | Admission free VRAM 39,024 MiB; final free/used 39,024/10,116 MiB; final disk free 29,649,981,440 bytes, above 10 GiB reserve; Point PIDs 12876/37381 remain; original coordinator repository SHA unchanged |
| Game/mobile integration, physical-device materials/performance, animations | NOT VERIFIED | Single game integrator owns this; no game files changed |
| New paid-image aircraft production | BLOCKED | No new monetary budget; free procedural reference used honestly |
| Full version 0.1 | NOT VERIFIED | This is an asset pipeline milestone |

The live inference script SHA-256 is `1746fa19eb12f4e85f6822cff3a82ca0badb0ac36d6b735a7164a2199eb5557b`. The milestone adds a pre-import guard for the exact compact component names, local conditioning/removal paths and inspected BiRefNet Python hashes. That guard passed against the actual installed model configuration; a third GPU generation was not performed merely to retest the guard. No new compatibility package was necessary.

The final plane spec includes `source_yaw_degrees: -90`. The initial attempt to apply this through imported object rotation did not alter the mesh; geometry hashes and top-view review exposed it. The corrected Blender stage rotates world-space vertex coordinates before scaling. Its real integration test verifies that a nonzero yaw changes the exported geometry. Corrective operations were journaled under distinct script hashes, with original and earlier outputs retained; no unknown operation was blindly repeated.
