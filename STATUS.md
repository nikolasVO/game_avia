# Game Avia — implementation status

2026-11-17. Actual native Godot prototype in `game/avia`, independent of the preserved coordinator/Unity proof. This is a vertical slice in progress, not accepted version 0.1.

| Stage | Status | Evidence / remaining work |
|---|---|---|
| A audit/engine | PASS prototype decision; external network BLOCKED | `docs/decisions/engine.md`, `docs/evidence/audit-20261117.md`; UDP external echo failed |
| B plane/server/two clients | PASS desktop localhost | Two distinct rendered client processes, separate headless server, both aircraft visible, common takeoff events; `docs/evidence/two-clients-desktop.json` |
| B Android | PASS build only; device NOT VERIFIED | Debug APK built with Godot 4.7.2 templates; static signature/alignment checks; no attached device |
| B iOS | BLOCKED | Xcode/SDK/signing absent; CommandLineTools only |
| C AI assets | BLOCKED | Paid bootstrap closed; gated DINOv3 access absent. No AI plane claimed; original procedural placeholders used |
| D flight cycle/rooms | PARTIAL | Shared takeoff/landing/crash model, recovery, public/private rooms and progress code implemented; 18 simulation/input checks PASS. Full network behavior tests pending |
| E content/modes | PARTIAL | Three procedural planes, shared terrain/runways, race/PvP server code, EN/RU UI, original engine tone; end-to-end mode acceptance pending |
| F quality | RUNNING | 16 active protocol bots / 30 minutes; phone/performance, poor-network and security acceptance remain open |
| G closed-test candidate | NOT VERIFIED | No store submission, no RC claim |

Paid calls this implementation: **0**. No purchases, terms acceptance, driver changes, GPU jobs, Telegram pollers, GitHub Actions or autodeploy.
