# Assets and runner readiness

An OpenLux GPT Image 2 returned reference is saved under assets/source. Its original PNG is 1254×1254 despite a 1024×1024 request; the usable reference is preserved, and exact-size capability remains blocked pending support clarification. The beveled cube under assets/catalog/blender-fixture is a separate procedural Blender fixture, not TRELLIS output. Its manifest includes GLB/preview hashes, measured triangle/material counts, LOD, axes, origin, dimensions and the absence of a Unity import test. Both source and optimized meshes are retained in Git LFS.

TRELLIS's installed CUDA environment passed a small tensor smoke, and flash-attn, CuMesh, FlexGEMM and nvdiffrast imported successfully. These are environment checks, not a completed generation.

Prepare a compact profile:

    python -m scripts.trellis_prepare
    python -m scripts.trellis_prepare --download

The metadata pass pins all four model repository revisions and selects six 512 components, sparse decoder, DINOv3 and BiRefNet. It excludes 1024/1536 flows and encoders before loader construction, uses explicit local snapshot/checkpoint paths and replaces the removal model configuration with MIT BiRefNet before from_pretrained. Selected download size measured 11,455,350,456 bytes (about 10.67 GiB); this excludes the already installed environment and working reserve.

DINOv3 initially returned gated HTTP 401. The owner has now received access approval: the pinned weights HEAD returned HTTP 200 with the previously saved private project Hugging Face token. That token is configured in the protected environment file (0600); no credential is in Git. All 20 selected compact512 files (11,455,350,456 bytes) are downloaded and their sizes checked. Real inference and asset integration remain separate, unaccepted checks. No gate bypass or substitute conditioning model is used. See [access/preparation evidence](../reports/hf-access-20261117.json).

The local asset API accepts a strict typed specification. References resolve inside repo/assets/source; path escapes, external symlinks, arbitrary shell fields and non-512 profiles are rejected. The runner uses a measured disk/VRAM guard, GPU lease and process heartbeat, runs the actual installed TRELLIS source, preserves original GLB, optimizes with Blender, records provenance/hashes and verifies measured budgets. Its full inference execution remains untested; the gated-weight prerequisite has now been resolved.

Historical Unity bootstrap evidence remains separate: Editor6000.3.28f1/URP17.3.0 is installed and owner activation now passed batchmode project creation; C#/GLB/build proof is not asserted. Godot4.7.2 remains the game engine. Actual native Android/macOS/Linux builds and their scope are documented in the game handoff; full Xcode/iOS remains blocked. Do not use the older bootstrap license failure or environment-only scope as current game status.

Asset example:

    {"asset_id":"prop_cube","purpose":"technical smoke","description":"one neutral toy cube","reference_images":["reference-smoke.png"],"triangle_budget":5000,"texture_budget":1024,"pipeline_type":"512"}

This becomes a durable asset task. prepared means metadata/specification accepted, verified means actual geometry passed, and completed additionally requires the remaining integration criteria.

Sources: [TRELLIS.2](https://github.com/microsoft/TRELLIS.2), [pipeline configuration](https://huggingface.co/microsoft/TRELLIS.2-4B/blob/main/pipeline.json), [bubblewrap isolation model](https://github.com/containers/bubblewrap).


Godot continuation: the actual validated TRELLIS safety-block GLB from task59adab633cd7 is imported with three LOD ranges and authoring collider hidden. Scale/pivot, vertices/normals/UV and1024 textures passed engine checks; two rendered gameplay clients passed. It is decorative, not authoritative collision geometry or an AI aircraft. Original/optimized hashes and provenance are in assets/catalog/trellis-safety-block; old beveled fixture remains procedural. No new paid/reference-image call was made. Subsequent native asset exports are a separate check.
