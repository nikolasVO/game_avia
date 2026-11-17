# Game Avia — verified prototype status, 2026-11-17

Historical published game/source/deployed server: **3417828170d35a3ab2acac0c3fc1ad5ab2bf1046**, Godot4.7.2 stable, protocol3. Continuation work below changes source; deployed/release SHA remains separately identified. **Version0.1 is NOT ACCEPTED.** This is an implemented vertical slice with real builds/server and explicit remaining gaps.

| Acceptance | Status | Actual evidence and limits |
|---|---|---|
| Canonical brief/receipt/audit | PASS | Exact SHA256/59144 bytes/34082 characters; actual shell verified; receipt outside Git; `docs/evidence/audit-20261117.md` |
| Engine/templates | PASS prototype choice | Official SHA512s, runtime exact version, native exports; `docs/decisions/engine.md` |
| Separate server and clients | PASS desktop/loopback | Distinct processes, common events, aircraft rendering; exported Thunder server plus two-client post-deploy smoke; protocol2/3 evidence kept separate |
| External network / mixed physical phones | FAIL / NOT VERIFIED | Actual Mac ENet/DTLS attempt to public endpoint UDP24567: joined=false/snapshots0; `external-game-protocol3.json`. No claim SSH/TCP proves UDP |
| Flight cycle | PASS shared simulation; partial integration |21 Godot checks:3 takeoffs, gentle landing, swept crash/boundary, checkpoint order, hit geometry, wire validation and synthetic3-pointer controls. Network takeoff/crash/recovery observed; full manual phone landing/feel NOT VERIFIED |
| Rooms | PASS loopback |19 processes:16 private members,17th rejected,2 public members isolated; `rooms-protocol3.json` |
| Race / repeat | PASS control bots | Two clients each completed two server-confirmed races, times~48.6s, numbered reliable recovery; `race-repeat-protocol3.json` |
| PvP | PASS minimal control-bot loop | Server hits/health/score/respawn observed with5 clients. Free-flight combat suppression checked separately; bounded-history lag compensation NOT IMPLEMENTED |
| Protocol safety | PASS tested cases; audit incomplete | Replay/expired tickets, plaintext/untrusted cert, invalid numeric/position/sequence packets, held recovery, rapid leave and version error tested. Additional per-packet delivery instrumentation FAIL is retained in `protocol-extended-failures.json`; no uncertain packet counted as rejected. Full arbitrary-packet/DoS fuzzing remains NOT VERIFIED |
|16 active clients /30 minutes | PASS exported server | Conservative1850 continuous seconds at16, minimum27628 snapshots/client, max reported simulation tick p953.398ms, maxRSS103.7MiB, maxCPU8.594% of one core. `native-load16-3417828.json`;32 players in one room NOT VERIFIED |
| Impaired UDP | PASS emulation | Protocol3 RTT100/200ms, jitter±30/50ms, loss1/3%, two clients retained; `protocol3-network-100/200.json`. Wi-Fi/cellular handover NOT VERIFIED |
| Persistence / backup | PASS tested scope | Global anonymous stats survive restart;2 races/48.5s restored. Protected coordinator AES-GCM backup restored20 tasks with integrity_check. No per-user persistent profile implemented |
| Android APK / AAB | PASS build/static checks | Clean checkout, debug APK57.1MB, actual unsigned release AAB52.4MB, v2/v3 signature, ELF/ZIP16KB static alignment, bundletool validation. Release signing /16KB runtime NOT VERIFIED |
| Android final runtime | FAIL in tested emulator | Earlier protocol2 emulator session took off and showed desktop peer. Final3417828 installs and joins, then stops controls under overloaded SwiftShader; hardware fallback produced Quickstep launcher ANR. This is not accepted Android gameplay or performance. Diagnostic APK was temporary and not published |
| iOS | BLOCKED | Full Xcode/SDK/TeamID/signing absent; actual export rejected missing TeamID; no Xcode project/IPA claimed |
| Physical mobile quality | NOT VERIFIED | No physical phones,20–30-minute thermals/FPS/memory, multi-touch/safe-area/handovers or renderer device choice |
| AI assets | BLOCKED | All3 planes are original procedural placeholders. Paid bootstrap closed, DINOv3 gated access absent; blocked jobs persisted in existing Store; no paid calls |
| Gameplay recording | PASS capture, limited scope | Live2-client desktop gameplay recorded with scripted controls.12.3 playback seconds captured over63 wall seconds; accelerated, Dummy audio, not FPS/mobile proof. `gameplay-recording.json` |
| macOS export | PASS headless runtime | Actual exported unsigned app joined separate server and received136 snapshots; `mac-export-runtime.json`. GUI/notarization acceptance separate |
| Repository/build restore | PASS tested scope | Clean checkout exports, Git LFS fsck and secret-pattern/path checks; exact release digests. Protected operational state/keys/caches/weights excluded |

Continuation milestone (containing fix commit): explicit ENet host bandwidth/channel setup repairs a measured Godot4.7.2 forwarding defect; invalid packets are now individually observed/rejected (`continuation-packet-fixed.json`,8 scenarios,6 command probes and bogus ticket). Timeout/background errors survive teardown; stale aircraft/audio and controls are cleared; three real reconnects and scene cleanup passed (`continuation-lifecycle.json`). Actual diagnostic APK60-second runs with/without3D all stayed connected and took off, but final clean-source/manual Android run is pending (`android-stall-isolation.json`). New off-host echo again FAIL (`continuation-external-udp.json`). DINO access application is pending Meta; no polling or paid probes. Unity activation passed, Godot retained.

The old16-client1850-second result remains a connection/snapshot measurement. The bandwidth defect means it must not establish sustained input delivery for current source. A new capacity run must additionally measure accepted input rate per client.

Known issues: Godot DTLS can log -30464 on departing peers; one stderr line interleaved inside a stdout health record. The original harness FAIL was preserved and reclassified after inspecting existing artifacts, without rerunning or altering measurements. Max correction metrics include intentional multi-kilometre server recovery teleports. Coast/water depth artifacts and primitive aircraft geometry remain visible. Desktop movie encoding and emulator overload measurements are not phone FPS.

Original API/coordinator/executor and Point GPU processes/data preserved. Reports use Store/outbox; no Telegram class/poller started. Paid calls0; no purchases/terms acceptance, app-store submissions, Actions, autodeploy or timers.

Historical final notification: **BLOCKED** by SSH `Permission denied (publickey)` after successful publication. GitHub artifacts/push are verified; final Store/event enqueue did not execute. Earlier9 reports were confirmed sent. Continuation restored explicit-identity SSH and enqueued a new task update. Parent owns reconciliation/delivery of that previous final event; it is not resent.
