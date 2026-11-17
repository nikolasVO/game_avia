# Native prototype handoff — 2026-11-17

Implemented by one actual filesystem/shell agent in the isolated branch `task/game-implementation-20261117`; main checkout preserved. Canonical brief SHA256 verified; receipt `/Users/nik/.codex/tmp/game-avia-implementation-20261117/receipt.json`. No sub-agent/model/account/API-key fallback or paid provider probe.

Game/release/deployment source: **3417828170d35a3ab2acac0c3fc1ad5ab2bf1046**. [Source branch](https://github.com/nikolasVO/game_avia/tree/task/game-implementation-20261117), [test artifacts](https://github.com/nikolasVO/game_avia/releases/tag/game-avia-prototype-20261117). Release is labelled prototype, **not accepted0.1**. Later reports/test-harness commits are separate from the compiled artifact SHA.

Now implemented: native Godot3D client; original procedural island/two strips/three planes; touch and keyboard control, chase/forward camera/drag look, settings/EN/RU/HUD/radar/synthesized engine audio; separate fixed30Hz authority; client prediction/replay and remote buffering; versioned ENet/DTLS, one-use bound tickets, input/rate checks and reliable idempotent recovery; public/private16-seat rooms; server checkpoints/times/repeat and minimal PvP health/hits/score/recovery; persistent anonymous global totals. No per-user account, free text, payments or runtime model inference.

Verified on actual processes:16 control bots held the exported server continuously1850s; max reported simulation tick p953.398ms, CPU max8.594% one core, RSS max103.7MiB, minimum27628 snapshots/client. Two bots each finished/repeated a race;5-client PvP produced server hits/score/recovery.19-client room test isolated16 private +2 public and rejected the17th private join. Input/ticket/version/recovery attacks and emulated100/200ms/1/3% UDP runs are separately recorded.32 in one room is NOT VERIFIED. Server telemetry has known DTLS shutdown diagnostics; see reconciliation in evidence.

Artifacts and SHA256:

| Artifact | Hash | Status |
|---|---|---|
| `game-avia-0.1.0-debug.apk` | `2b242ce26c862d92a4d4c548b0ac01b557c9c4330235b8ca9446395e62c07f24` | Clean native export; debug signed; final emulator gameplay FAIL |
| `game-avia-0.1.0-unsigned.aab` | `fe5fe0e9ca28efc75eddf5b8a3a6164caa783b0d5f0252ad57b77df634a206b9` | Actual release bundle, unsigned; bundletool validation PASS |
| `game-avia-server.x86_64` | `5b884ac8ceae4c26821403c815a9361fed5afd6b8746a9fefbbcbc7840c01346` | Deployed/loaded native headless server PASS |
| `GameAvia.zip` | See `docs/evidence/artifact-index.json` / release SHA256SUMS | Unsigned macOS app export; actual headless app runtime PASS |
| `game-avia-desktop-small.avi` | `56681838b5a9885e64a04e4f1b32b994841d318f4272c8bff6272b855d33c9cc` | Live scripted2-client gameplay; accelerated12.3s playback from63s capture; no FPS claim |

APK/AAB are ARM64+x86_64, package `com.nikolasvo.gameavia`, version0.1.0/code1, min24/target36. Static16KB ELF/ZIP alignment passed;16KB runtime NOT VERIFIED. Godot4.7.2 standard engine/templates SHA512 verified. Actual macOS build is not signed/notarized for public distribution.

Launch/build instructions are in README. Manual deployment/health/update/rollback are in `docs/game-operations.md`. Current service `game-avia-flight` runs as ubuntu on Thunder UDP24567; separate config/socket/logs/progress/key. Original coordinator/API/executor PIDs and Point GPU processes were preserved. Post-deploy two-client smoke PASS. External actual ENet/DTLS from Mac to public endpoint FAILED; provider UDP mapping remains BLOCKED. Nothing in SSH or loopback results proves public access.

Android honesty: an earlier protocol2 APK installed, rendered a desktop peer and actually took off. Final3417828 APK installs/joins and displays the peer, but its tested SwiftShader session stopped control updates. The Mac was under high memory/CPU pressure; a lower-resolution host-graphics fallback also produced a Quickstep launcher ANR. Cause is not conclusively isolated. Failed/static Android recordings are not the accepted gameplay clip. Physical devices and20–30-minute mobile metrics remain NOT VERIFIED. The owned emulator was stopped after testing to release resources.

iOS: only CommandLineTools; actual xcodebuild failed and export rejected missing TeamID. No Xcode project/IPA/archive/TestFlight result. AI:3 procedural placeholders with manifests, not TRELLIS planes; paid bootstrap closed and DINOv3 approved access absent. Blocked asset jobs use existing Store. Paid calls during implementation0.

21 Godot simulation/wire/synthetic-touch checks and36 infrastructure tests passed separately. A protected encrypted off-server coordinator snapshot restored20 tasks with integrity_check; key/DB remain outside Git. Git LFS fsck, clean native exports and static secret/package scans passed in their documented scope. No raw provider response, model/cache, operational DB, private chat ID or key is a Git/release artifact.

Next work is the prioritized `docs/backlog.md`: resolve final Android runtime; external UDP; physical-phone full flight/control/performance; real AI asset chain; iOS toolchain/signing; remaining protocol/lag/renderer quality and privacy/operator facts. No store submission, subscription, refill, new hosting, account-terms acceptance, timer/Action or autodeploy was performed. This handoff does not mark the owner's full0.1 brief complete.
