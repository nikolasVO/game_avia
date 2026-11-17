# Game Avia — development continuation, 2026-11-17

**Full development scope is IN PROGRESS, not accepted.** Active task68c406f99772. Current brief: docs/briefs/game-avia-development-20261117.md. Stage3 is queued only after full acceptance. Godot4.7.2 retained.

New work: data-driven24-fighter+3-original catalog; six selectable procedural fighter prototypes; shared forces/inertia/altitude/AB/airbrake/flaps/gear; server-locked assistance category; protocol4 with84-byte full prediction state; native comparison hangar and synthesized class tones. Scripted comparison passed40 checks and original23 checks remain PASS. Actual current rendered/network/native build checks are in progress. No named fighter is accepted under all15 gates.

Preserved exact APK6c3620a runtime:90s emulator,2662 commands/1344 snapshots/two peers/own takeoff PASS; frame p5079.122ms,p95141.271ms, FPS target FAIL. Cold-render8.58s stall reproduced before fix; automatic admission now waits first rendered frame. docs/evidence/android-runtime-r3.json and android-cold-render-regression.json. Physical Android/iPhone NOT VERIFIED; external UDP FAIL; iOS/Xcode/signing BLOCKED. Deployed flight remainsc1922c7/protocol3; new code is not yet deployed. No capacity claim transferred from old authority to new fighters.

24 asset jobs are durable in existing Store; no paid image calls. DINO approved and real AI aircraft candidate exists in separate reviewed handoff; full production aircraft/mobile integration remains incomplete. AI safety-block prop passed native emulator scene import. [Production backlog](docs/backlog.md), [GDD](docs/design/gdd-development.md), [catalog](docs/design/aircraft-catalog.md).

---

Historical r2 evidence below retains its original scope/source; it is not a current protocol4 acceptance report.

# Game Avia — prototype r2, 2026-11-17

**Version 0.1 is NOT ACCEPTED.** Current game/release/deployed flight server: `c1922c74a29112818ce9ee523a9cdc81eb211180`, Godot `4.7.2.stable.official.ed1daf0bf`, protocol3. Later evidence/test-fixture commits do not change exported gameplay. [Builds and hashes](docs/evidence/artifact-index-r2.json), [handoff](docs/handoffs/game-prototype-r2-20261117.md).

| Acceptance | Status | Evidence and exact scope |
|---|---|---|
| Full brief / receipt / audit | PASS | Original59144 bytes/34082 characters/SHA256 verified; initial and continuation receipts outside Git. Unity license probe now PASS, Godot retained. |
| Engine/templates | PASS prototype choice | Exact official engine/templates, real native exports. Compatibility provisional; physical-phone renderer/minimum devices NOT VERIFIED. |
| Dedicated server / clients | PASS native loopback | Exported Linux c192 server, two real clients before/after manual deployment. `native-smoke-c1922c7.json`, `deployment-c1922c7.json`; rendered two desktop clients in `procedural-native-flight.json`. |
| External UDP | FAIL | Fresh Mac→public Thunder UDP24567 clients after c192 deployment: joined=false, snapshots0. Separate off-host echo also timed out. `external-game-c1922c7.json`; mapping/firewall path unknown, no TCP tunnel called UDP. |
| Flight / touch | PASS tested cases; partial manual acceptance |23 shared/synthetic checks including three takeoffs, gentle landing, swept impact, race order, hit geometry, wire validation, independent pointers and context brake. Actual Android touch takeoff/background/rejoin/recovery; full manual phone landing/feel NOT VERIFIED. |
| Client lifecycle | PASS tested cases | Specific timeout/pause reasons survive transport teardown; stale aircraft/audio/prediction cleared. Seven real reconnect/scene checks; actual Android Home/resume/touch rejoin in both9412 andc192 APKs. Carrier handover NOT VERIFIED. |
| Rooms | PASS prior protocol3 test |19 real processes:16 private,17th refused,2 public isolated. Matching code unchanged by bandwidth fix. `rooms-protocol3.json`;32 players in one room NOT VERIFIED. |
| Race / repeat | PASS control bots | Current c192 recheck: two clients each finished two races at~48.6s (`race-repeat-c1922c7.json`); old source test retained separately. Server confirms order/time/recovery, no client score authority. |
| PvP / peaceful mode | PASS minimal tested loop | Current c192:5 clients,156 server hits,39 scores,36 recoveries.150 accepted fire inputs in peaceful room emitted no shot. `pvp-c1922c7.json`, `continuation-protocol-final.json`. Bounded-history lag compensation NOT IMPLEMENTED. |
| Protocol validation | PASS9 scenarios; audit incomplete | Actual receipt/rejection by sender and unique sequence for six malformed control packets plus bogus ticket; replay/expired admission observed separately. Plaintext/wrong certificate/version/held-recovery/rapid-leave tested. `continuation-protocol-final.json`. Prior missing-packet FAIL retained; full hostile-packet/DoS audit NOT VERIFIED. |
|16 active clients /30 minutes | PASS exact9412 exported server |1850 continuous seconds at16,887989 accepted inputs (~29.9996Hz/client), max reported simulation-body p953.352ms, maxRSS92MiB, maxCPU8.197% of one core. `native-load16-9412be7.json`. c192 authority files byte-identical; its actual binary passed separate smoke. `authority-source-comparison-r2.json`. |
| Impaired UDP | PASS emulation | Current source: RTT100/200ms, per-direction jitter±30/50ms, loss1/3%, both clients retained and inputs acknowledged. `continuation-network-100/200.json`. Not carrier/Wi-Fi handover. |
| Persistence / backup | PASS tested scope | Deployment preserved114 flights; two clients increased totals to116. Protected pre-upgrade backup retained. Prior separate race restart restored two finishes/48.5s. Coordinator encrypted off-server backup/restore verified20 tasks at earlier milestone; no per-user persistent account. |
| Android APK / AAB | PASS build/static | Clean c192 APK57.1MB, actual unsigned AAB, v2/v3 signature, ELF/ZIP16KB alignment, official bundletool validation. `android-static-c1922c7.json`. Release signing and16KB device runtime NOT VERIFIED. |
| Android runtime | PASS emulator scenarios; FPS target FAIL | Clean9412 APK300s:8115 commands/4045 snapshots. Clean c192 APK120s:2971 commands/1552 snapshots,2 peers, touch takeoff/Home/rejoin. Frame p5069.338ms/p95152.468ms for c192 SwiftShader, not30FPS. `android-runtime-c1922c7.json`; old341 FAIL preserved separately. |
| Gameplay recording | PASS actual capture, limited scope | c192 Android screenrecord18.7417s/640×360, decoded frame inspected, normal media time, no acceleration. Emulator/scripted input, not phone/human play. Previous accelerated desktop AVI retained with its scope. |
| macOS / iOS | PASS mac headless / BLOCKED iOS | Actual unsigned macOS export joined and received210 snapshots. `mac-runtime-c1922c7.json`. Full Xcode/SDK/TeamID/provisioning absent; no exported iOS project/IPA/TestFlight claimed. |
| Physical mobile quality | NOT VERIFIED | No Android device in ADB; USB iOS enumeration returned errors and does not establish absence. No physical20–30-minute heat/frame/memory, multi-touch, safe-area/tablet or handover proof. |
| Assets | PASS procedural fallback / AI BLOCKED | Original near meshes276/276/304 triangles and96-triangle distant LOD, animated props, finite mesh data and actual rendered flight. Manifests in assets/procedural. Parent1f0dd2d confirms approved DINO/installed weights. A real TRELLIS safety block is now imported/tested in Godot desktop; aircraft remain procedural. No new gate/API call by integrator. Latest-asset native exports pending; c192 release remains separately verified. |
| Repository / publication | PASS tested scope | Main integration, non-force pushes, LFS checks, remote digests and APK redownload verified; separate clean c192 checkout exported successfully. Archive bytes differ in generated scene IDs/ZIP/signature metadata (`clean-rebuild-c1922c7.json`); no bit-identical claim. Secrets/keys/DB/weights/caches excluded. `artifact-index-r2.json`. |

The Godot max_channels→incoming-bandwidth forwarding defect caused real unreliable input starvation; explicit host bandwidth/channel setup fixes it (`enet-bandwidth-defect.md`). The old341 load remains historical connection/snapshot evidence, not sustained-input capacity. New9412 measurements are separate.

Known limits: engine DTLS logs -30464 on departing peers (recorded, not hidden); simulation-body p95 excludes work outside that method; large correction metrics may include intentional recovery teleports. Production AI assets/audio, PvP history compensation, hostile-packet audit and physical flight/thermal QA remain open. The game is a prototype, not a release candidate.

Flight service alone was manually updated. API/coordinator/executor remain at97bd7dd, healthy; Point processes/data/models preserved. Reports/artifacts use Store/outbox and sole coordinator; new reports confirmed sent. Parent's old handoff_final was confirmed sent and was not resent. Paid calls0, no purchases, new terms, store submission, Actions, timers or autodeploy.

Late asset continuation: actual existing image→TRELLIS→Blender safety block imported with LOD/material/UV/normal/pivot validation and two rendered clients. `ai-prop-godot-import.json`. The real cache repeat exposed JSON list/tuple mismatch; fixed normalization/input hash/model revision guard, six tests and actual cached reuse PASS with zero new inference. Running coordinator is preserved. No AI aircraft claim; no new paid image call.
