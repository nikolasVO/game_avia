# Assets and runner readiness

An OpenLux GPT Image 2 returned reference is saved under assets/source. Its original PNG is 1254×1254 despite a 1024×1024 request; the usable reference is preserved, and exact-size capability remains blocked pending support clarification. The beveled cube under assets/catalog/blender-fixture is a separate procedural Blender fixture, not TRELLIS output. Its manifest includes GLB/preview hashes, measured triangle/material counts, LOD, axes, origin, dimensions and the absence of a Unity import test. Both source and optimized meshes are retained in Git LFS.

TRELLIS's installed CUDA environment passed a small tensor smoke, and flash-attn, CuMesh, FlexGEMM and nvdiffrast imported successfully. These are environment checks, not a completed generation.

Prepare a compact profile:

    python -m scripts.trellis_prepare
    python -m scripts.trellis_prepare --download

The metadata pass pins all four model repository revisions and selects six 512 components, sparse decoder, DINOv3 and BiRefNet. It excludes 1024/1536 flows and encoders before loader construction, uses explicit local snapshot/checkpoint paths and replaces the removal model configuration with MIT BiRefNet before from_pretrained. Selected download size measured 11,455,350,456 bytes (about 10.67 GiB); this excludes the already installed environment and working reserve.

DINOv3 returned gated HTTP 401. The weight download is blocked until the owner has accepted its terms and configured an authorized HF_TOKEN in the private server file. No access bypass or substitute conditioning model is used. Large public weights were not downloaded while that prerequisite was missing.

The local asset API accepts a strict typed specification. References resolve inside repo/assets/source; path escapes, external symlinks, arbitrary shell fields and non-512 profiles are rejected. The runner uses a measured disk/VRAM guard, GPU lease and process heartbeat, runs the actual installed TRELLIS source, preserves original GLB, optimizes with Blender, records provenance/hashes and verifies measured budgets. Its full inference execution remains untested due to gated weights.

Future output must still complete GitHub/LFS artifact sync, Unity import/build and target-device checks. Unity Editor 6000.3.28f1 (Intel) and Hub 4.0.1 have now been installed on Mac from signed official downloads. Editor version execution passed; a real batchmode launch exited 198 with no valid Editor license. URP 17.3.0 is bundled with this Editor. The manual outbound-SSH runner and pinned glTFast 6.15.1 proof project are prepared, but their Editor C# import/build has not run past licensing. Full Xcode is absent. There is no real Unity, Android or iOS build in this milestone. See [Mac runner](mac-runner.md). No game genre, control scheme, art direction or store release is inferred from the project name.

Asset example:

    {"asset_id":"prop_cube","purpose":"technical smoke","description":"one neutral toy cube","reference_images":["reference-smoke.png"],"triangle_budget":5000,"texture_budget":1024,"pipeline_type":"512"}

This becomes a durable asset task. prepared means metadata/specification accepted, verified means actual geometry passed, and completed additionally requires the remaining integration criteria.

Sources: [TRELLIS.2](https://github.com/microsoft/TRELLIS.2), [pipeline configuration](https://huggingface.co/microsoft/TRELLIS.2-4B/blob/main/pipeline.json), [bubblewrap isolation model](https://github.com/containers/bubblewrap).

