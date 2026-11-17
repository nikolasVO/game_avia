# Game Avia development GDD

Active scope: [unaltered owner development brief](../briefs/game-avia-development-20261117.md), SHA256 `6da6bd4feaa7573f87564eeba4971c80de09e8427b3defca726e73c4df7ec4db`. This document describes the implementation direction, not accepted delivery. Godot4.7.2/GDScript/Compatibility stays selected. Stage3 is queued separately and must wait for full current-stage acceptance.

## Experience and progression

Quick guest entry → choose aircraft/room → take off → fly/explore/race or select peaceful mission → land/recover → review results. A 5–15 minute session must offer an achievable objective. Basic free flight remains available without licenses. Career ranks: novice, student, private, commercial, experienced, master, legend. Licenses unlock training/career challenges; future rewards, XP, credits and unlocks are exclusively server owned. No purchases or unrestricted text/voice chat.

## Fleet

One catalog owns 24 named fighter variants plus Kite, Tern and Swift. Configuration is not aircraft acceptance. The first six flight prototypes are F-16C, Su-27, F-15C, Su-35S, Rafale C and Gripen C. Remaining variants have full proposed balance records but are not selectable until their gameplay/model checks pass. Every entry records source/status; all new flight values are authored arcade balance. Public reference facts are separate from game parameters.

Distinct qualities: F-16 quick control response; Su-27 slower inertia response and steadier slip damping; F-15 thrust/climb with heavy handling; Su-35 low-speed thrust-vector assist; Rafale canard delta with balanced landing; Gripen small canard delta and lower landing speed. Production models require recognizable geometry, source review, LODs, sound, flight/landing/network/phone/hangar checks and Telegram/GitHub evidence. No entry is accepted merely by the current scripted flight test.

## Flight and controls

Metres, seconds, radians; nose -Z, +Y up; fixed30Hz shared simulation. Original three retain legacy force parameters. Fighter model adds speed-squared lift, angle of attack, stall, exponential density, throttle thrust, induced/manoeuvre/gear/flap drag, angular inertia, afterburner, airborne speed brake, gear-dependent landing tolerance and deterministic light wind. Speeds in JSON are km/h converted to m/s once used. Maximum sea/altitude speeds calibrate drag/soft envelope; actual velocity comes from acceleration. Cruise and climb figures are pilot guidance; they are not velocity assignments. Handling scores0–100 map explicitly to response times, rates, stability damping and landing/takeoff tolerance.

Arcade stabilizes bank/pitch and lowers nose during a stall; Realistic reduces automatic attitude assist and increases manoeuvre energy loss; Expert removes attitude help, further reduces slip damping and expands the lift envelope. More detailed system/handling depth remains open. Free rooms can select category at admission; competitive rooms force Arcade. Client input cannot carry category or arbitrary physics settings. Mobile two-thumb control remains, with separate system toggles. Physical feel/safe areas/multitouch remain mandatory device checks.

## Server and state

Dedicated ENet/DTLS authority,16 per room. Inputs carry bounded sequenced controls, never coordinates/results. Version4 changes input schema and snapshot bit fields. Snapshots remain84 bytes/player: angular rates packed as signed8-bit values at1/32 rad/s; full precision is retained inside simulation to preserve small-input response. Reconciliation tolerates at most1/64 rad/s packing error per axis, assist/system flags share the existing bit field. Old clients fail version negotiation. Room modes/race times/hits/respawn stay authoritative. New progression/mission rewards must enter through server rules plus idempotent persistence; no client reward RPC is planned. No public multiplayer acceptance until two off-host clients actually fly together.

## Content and world gates

Start archipelago: preserve existing sea/island/runways/race, then author city/port/lighthouses/rescue/delivery landmarks after profiling. Northern mountains, desert, city and volcanic island are separate planned regions. Do not expand active map size before starter-region physical performance verification. Production queue uses existing Store and asset pipeline. The latest owner authorization permits paid development/generation through existing connected balances beyond the old bootstrap; requests remain bounded and unknown prices remain cost_unknown. Authored references and TRELLIS progress with resource leases/reserve. Existing original AI aircraft candidate is a separate integration candidate, not a fighter replica.

## Missions and social scope

Thirty distinct missions from brief section8: five training, five delivery, five rescue, five races, five jet challenges and five exploration/co-op. They require actual server objective transitions, reconnect persistence and verified reward grants. Current prototype has race/minimal PvP only. Career, mission runtime, daily/weekly goals, pilot log, friends, co-op and timed events remain production backlog. PvP expansion includes duel/team modes, abstract missiles/lock/ammo and assists; no real weapons simulation is required. Peaceful rooms always suppress combat.

## Interface and quality

Native landscape UI, English/Russian; selection/comparison hangar with explicit game balance, units switch, simple/advanced HUD. Expanded navigation is added only alongside working features. No empty career/friends buttons presented as complete. Original cached synthesis now provides nine distinct engine profiles for the playable fleet, smooth throttle/camera response, wind, afterburner, stall warning and bounded startup/gear/landing/crash cues. Five local players and four nearest live remote engines bound voice count. Digital mixer/lifecycle checks are separate from subjective sound and physical-device acceptance; remaining aircraft and characteristic animation targets stay open. Renderer/device choice,30FPS baseline,60FPS option, thermal/memory/network measurements and all15 aircraft gates determine acceptance. Emulator rendering is useful regression evidence and cannot close phone acceptance.

## Releases and blockers

Maintain rollback to published r2/c1922c7 and preserved6c3620a APK evidence. Protocol4 must not be deployed over protocol3 without a matching client artifact and explicit manual health/rollback checks. Current external UDP path and physical-device/Xcode/signing dependencies remain open. No store publication or new paid infrastructure is authorized; existing provider-balance development/generation is authorized by the latest owner instruction. STATUS/backlog/evidence separate PASS/FAIL/BLOCKED/NOT VERIFIED and identify exact source/runtime.

Client resilience update: selected aircraft material variants are rendered before admission; the client explicitly polls queued snapshots before evaluating their5s wall-age deadline. Server poll/simulation clock stays independent. A5.5s blocked-client test must recover using actual queued packets while server time advances. Late warmup must not reconnect after focus/background cancellation.
