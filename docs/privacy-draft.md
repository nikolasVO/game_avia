# Prototype data map and privacy draft — 2026-11-17

This is the implemented prototype's data inventory and a preparation document. No store form has been submitted. The operator's legal identity, support/deletion contact and public policy URL are **BLOCKED: owner fields missing**. Complete these and recheck the final binary/hosting configuration before publication.

| Data | Why / where | Retention / removal |
|---|---|---|
| IP address / UDP endpoint | Needed by ENet/DTLS while connected; host/provider can see connection metadata | App code does not intentionally persist IP addresses; provider access-log practices remain NOT VERIFIED |
| Random peer ID, generated callsign, room/mode, movement and input | Multiplayer operation; server RAM and bounded diagnostic logs | Entity removed on disconnect or 10 s input timeout; game log rotates at 5 MB, 3 backups (up to ~20 MB). Proposed time retention 7 days is not yet enforced by a scheduled job |
| Private friend code | Selects a room; encrypted in transit by DTLS | RAM/room events in diagnostic log; not a password or permanent account secret |
| Flight / landing / race counts and best race time | Anonymous global server totals in protected `progress.json`, atomically replaced | Persistent across service restart; contains no per-player account or identifier |
| Sensitivity, inversion, handedness, quality, sound, last host, language | Local `user://settings.cfg` | Cleared by OS “clear app storage”/uninstall; not uploaded by a profile API |
| Error, tick, connection, network and correction diagnostics | Development/operation and testing | Bounded server logs; test evidence contains protocol bots/owner emulator only |

No phone/email login, public nickname text, free text/voice chat, advertising, purchases, ad ID, location permission, contact access, analytics or crash-report SDK is implemented. Android exports request INTERNET. Godot receives no gameplay telemetry from our application code. The backend does receive gameplay data; “no data collected” is not an appropriate blanket claim.

There is no persistent server account/profile in this slice. Consequently there is no implemented account deletion API and no claim that logout deletes an account. If per-user progression/accounts are added, in-app deletion plus a public request path must be completed before the corresponding store release. Anonymous global totals cannot be attributed back to an individual by this schema.

Draft policy wording: “Game Avia connects to a flight server to synchronize aircraft and game rules. Connection identifiers, room information and flight state are processed to operate multiplayer and diagnose errors. Anonymous aggregate flight and race results are saved. Preferences stay on your device. We do not sell gameplay data or include advertising. Contact: [OWNER TO FILL]. Operator: [OWNER TO FILL]. Hosting provider and applicable retention: [OWNER TO CONFIRM].” This is not a final published policy.

Preparation for Apple App Privacy / Google Data safety: assess gameplay/app interaction data, diagnostics and ephemeral identifiers for app functionality and security, including provider logs; do not mark third-party “sharing”/tracking from guesswork. DTLS is tested on desktop and Android emulator only; iOS transit protection remains NOT VERIFIED. No advertising tracking is implemented. The complete final answers require the operator/provider facts and final SDK audit.

Checked primary sources: [Apple App Privacy](https://developer.apple.com/app-store/app-privacy-details/), [Google Data safety](https://support.google.com/googleplay/android-developer/answer/10787469), [Apple account deletion](https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion), [Google account deletion](https://support.google.com/googleplay/android-developer/answer/13327111). Store declarations cover actual behavior, including third-party SDKs; they are not inferred merely from a preset.
