# Provider evidence and limits

config/providers.yaml preserves the owner's exact logical order and wire mapping. The primary GPT pool is GPTGE, OpenLux, WhatsToken, Xinfeng, XYC model-by-model; reserves follow only after the primary pool. GPTGE CODEX/Claude and APIBOST begin balance-blocked from the owner's latest audit. A shared hostname does not merge billing scopes. Xinfeng/XYC Claude remain quarantined.

Only the first logical GPT route on OpenLux and WhatsToken and the first Claude route on OpenLux passed this implementation's live tool-result continuation proof. The other IDs retain the supplied text audit and are not promoted to agent readiness. WhatsToken's verified GPT wire ID is gpt-6.1-sol-pro. Alternative logical models use their exact configured suffixes.

The verified cloud worker uses an explicit Chat Completions tool loop with allowlisted tools. Claude has its own route pool. It is not represented as official Codex CLI compatibility.

Official Codex CLI 0.169.0 is installed and a Responses adapter is implemented. OpenLux's Responses probe ended in a transport failure. The first WhatsToken CLI probe used the logical ID and is invalid as evidence for its channel-specific wire ID; the adapter was corrected, but a new probe was not run after the 12-request bootstrap cap was exhausted. Official Codex runtime readiness therefore remains unverified. Do not pass a raw /models catalog to Codex or claim Responses readiness from Chat Completions success.

All image groups start catalog-only. One OpenLux gpt-image-2 generation succeeded and produced the saved reference. Image edit, Nano/Gemini, Seedream and async image job contracts remain unverified; they are not sent a generic payload. A possibly charged unknown image operation is never automatically resubmitted.

Balance and auth failures block the corresponding confirmed billing scope; a 403 is not assumed to mean balance. Model/capability failures are route-specific. Breaker state, cooldown and evidence persist in SQLite. The route pool is finite, at most 32 candidates, with a smaller per-task request/deadline limit. A policy refusal stops the pass. Opaque thinking/signatures or response IDs are not transferred between providers.

12 text HTTP attempts and one image generation were reserved during bootstrap. Two Responses outcomes may be unknown; no monetary total is inferred. The ledger's bootstrap token values are reservations, not recovered actual usage. Future successful Chat Completions responses save allowlisted actual token usage separately. Unknown tariffs/currency remain cost_unknown; no price is treated as zero, no balance refill or plan change is automated.

Official implementation references: [Codex SDK](https://learn.chatgpt.com/docs/codex-sdk), [Codex configuration](https://learn.chatgpt.com/docs/config-file/config-reference), [GPT Image 2 provider endpoints](https://gpt.ge/en/models/gpt-image-2), [Telegram Bot API](https://core.telegram.org/bots/api).

