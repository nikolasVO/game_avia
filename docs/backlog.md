# Development production backlog

Active task68c406f99772, full21-section development brief. Current stage remains in progress; stage3 waits for complete verified acceptance. [GDD](design/gdd-development.md), [catalog](design/aircraft-catalog.md), [source audit](design/aircraft-sources.md). Previous prototype backlog preserved in handoffs/backlog-before-development-20261117.md.

|Priority|Work|Status / gate|
|---|---|---|
|P0|Existing external UDP24567|FAIL actual off-host; provider mapping unknown. Two external playing clients required.|
|P0|Physical Android/iPhone controls/frame/memory/heat/handover|NOT VERIFIED; no available validated device path. Emulator cold-render connection regression fixed6c3620a and90s actual flight PASS, FPS FAIL.|
|P0|Android intermittent black resume|FAIL reproduced1cf APK; identical binary repeat and5c control PASS. Stock isolated3D fixture also stalled; generation recovery passed20fixture cycles and85s actual game Home/rejoin. Separate120s Su27 AI touch flight had later render slowdown/disconnect FAIL (with one concurrent editor import); fresh controlled AVD run pending. Preferences/menu agreement fixed with6actual desktop UI checks, APK proof pending. No physical/universal-fix completion claim.|
|P0|Rollback|PASS real5c→c192→5c rollback with two matching clients at each phase and116→124 aggregate preservation. r2 remains available; final flight5c/protocol4, full acceptance still incomplete.|
|P0|Existing AI candidate|Original AI candidate parked in scene; F-16C real inference and symmetry/LOD/import/render/native integration PASS, production recognition/articulation/mobile gates open. Su-27 local inference/Blender12view validation and two AI game clients PASS; both bodies remain incomplete15-gate candidates. AI safety-block prop already in actual6c APK.|
|P1|27-entry unified catalog|Implemented data/loader;24 named fighters, originals preserved. Validation and game delivery gates separate.|
|P1|Six flight profiles + systems|Implemented shared forces, inertia, AB/airbrake/flaps/gear/profile authority; scripted comparison PASS. Real protocol/rendered pair and f702 native load PASS in their scopes; physical handling/landing remains open.|
|P1|F-16C vsSu-27|Distinct measured flight prototypes. F-16C AI candidate body integrated with procedural gear/effects; actual rendered F-16C/Su-27 pair PASS. Clean5c0df28 APK120s real emulator PASS for flight/system taps; actual Home/resume/rejoin PASS. All15 production gates remain open. Native six-client full circuits/6server landings/0crashes passed, separate from human/phone handling.|
|P1|3D comparison hangar|Implemented first native inspection/comparison view; visual/input QA in progress. Filters/favorites/paint/unlocks/upgrades pending. Pin Join/Hangar outside settings scroll after actual resumed-menu UX gap.|
|P1|Server4 regression/load|f70216 active fighter clients1850s PASS, health-airborne/cycle checks and CPU/RAM retained. Protocol/lifecycle/current rendered pair PASS in recorded scopes. Recheck remaining modes/clean native release; no repeated long load for visual-only changes.|
|P2|Other18 fighters|Proposed configs only. Primary variant/source audit, own reference, model repair, individual dynamics, sweep geometry/aero, animation/audio/LOD and all15 gates required.|
|P2|Production assets|24 durable jobs in Store KV aircraft_production_queue:v1; no automatic worker/paid image. Reference→lease/reserve→TRELLIS→Blender→Godot→phone QA. Keep stable jobs through retry/restart.|
|P3|Career/profile/progression|Server-owned persistent profiles, secure restore/delete, seven ranks, six licenses. No client-assigned reward or license gate on free flight.|
|P3|30 missions|Implement runtime objectives/rewards/repeat/reconnect; actual full completion tests. No config-only mission acceptance.|
|P3|Journal/daily/weekly/achievements|After authoritative progression, bounded cadence/idempotent rewards.|
|P4|Starter archipelago quality|Existing island is prototype; activities/landmarks pending. Gate size expansion on real phone profile.|
|P4|Other four regions|PLANNED, blocked on starter-region quality/performance gate.|
|P5|Friends/co-op/team racing/PvP/events|Implement separate bounded milestones over existing authority; no new capacity promise.|
|P6|Release/testing/signing/rights|Physical20–30min sessions, full Xcode/SDK/signing, Android AAB/releasekey,16KB runtime, internal testing rights, commercial name/design/material review. No store submission.|

Common quality: EN/RU, readable native mobile layout, speed/altitude unit settings, simple/advanced HUD, flight sounds/warnings, fixed-step fairness, malicious input/version/ticket/rate validation, guarded resource use. Keep persistence restore/secrets/LFS/clean-rebuild checks current. All15 aircraft checks in owner section20 remain mandatory. Scripted touchdown fixtures do not prove a human landing.
