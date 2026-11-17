# Development production backlog

Active task68c406f99772, full21-section development brief. Current stage remains in progress; stage3 waits for complete verified acceptance. [GDD](design/gdd-development.md), [catalog](design/aircraft-catalog.md), [source audit](design/aircraft-sources.md). Previous prototype backlog preserved in handoffs/backlog-before-development-20261117.md.

|Priority|Work|Status / gate|
|---|---|---|
|P0|Existing external UDP24567|FAIL actual off-host; provider mapping unknown. Two external playing clients required.|
|P0|Physical Android/iPhone controls/frame/memory/heat/handover|NOT VERIFIED; no available validated device path. Emulator cold-render connection regression fixed6c3620a and90s actual flight PASS, FPS FAIL.|
|P0|Rollback|Published r2/c1922c7 and6c3620a APK/evidence preserved; do not replace deployed protocol3 before tested matching client/server4.|
|P0|Existing AI candidate|Real inference/LOD/import evidence available8aa3635; review branch handoff, integrate separately; production geometry/articulation/mobile gates open. AI safety-block prop already in actual6c APK.|
|P1|27-entry unified catalog|Implemented data/loader;24 named fighters, originals preserved. Validation and game delivery gates separate.|
|P1|Six flight profiles + systems|Implemented shared forces, inertia, AB/airbrake/flaps/gear/profile authority; scripted comparison PASS. Real current protocol/render/build verification in progress.|
|P1|F-16C vsSu-27|Procedural recognition prototypes; compare identical commands, then two actual clients and native APK. Production acceptance remains open.|
|P1|3D comparison hangar|Implemented first native inspection/comparison view; visual/input QA in progress. Filters/favorites/paint/unlocks/upgrades pending.|
|P1|Server4 regression/load|Run protocol/lifecycle/race/PvP/impaired tests; changed authority requires new bounded load before capacity claims. Keep old9412 measurement separate.|
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
