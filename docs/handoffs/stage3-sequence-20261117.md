# Sequential execution of the owner's stage 3

The owner explicitly requested: finish the current development prompt, then take the next one. The next prompt is preserved verbatim at `docs/briefs/game-avia-stage3-20261117.md`: 56,012 UTF-8 bytes, 31,892 characters, SHA256 `8b887eabbacb46051ccd19fdcb2c8f69f84aacbd27e41be91469e4fd2c4fc379`. Its adjacent receipt identifies the source and activation condition. Its immediate-execution section applies only AFTER the predecessor is accepted.

## Order and acceptance

1. Current manual task `68c406f99772`: the complete development brief, `docs/briefs/game-avia-development-20261117.md` (SHA256 `6da6bd4feaa7573f87564eeba4971c80de09e8427b3defca726e73c4df7ec4db`). Continue it now. Do not interrupt it or replace its scope.
2. Stage 3: a separate durable manual task, discoverable through Store KV `game_stage3_task`, with a real dependency on `68c406f99772`. The entire next prompt is also stored in its specification. It remains blocked with result `waiting_for_verified_predecessor`; the bounded Python executor cannot claim it.
3. Release stage 3 only when ALL predecessors have `status=completed`, `verification_status=passed`, and `github_sync_status=synced`. A CLI exit, first milestone, plan, blocked device, failed test or unavailable service does not release it. Do not declare the current brief complete to get past the gate. Record full acceptance evidence in its result and send the final current-stage report through the existing outbox.
4. End the current CLI turn after genuine current-stage completion. The one-shot local dispatcher waits for that writer to exit, atomically reserves the successor, checks the entire next brief and resumes the SAME session/worktree with the complete stage-3 text. A second running CLI writer prevents launch. No parallel game integrator is created.
5. The stage-3 agent must verify the exact bytes/hash, write its receipt, keep its task lease alive, update the active-brief pointer, and continue implementation. The reservation/start report is not a full-brief receipt or acceptance.

Current agent: read this sequencing instruction when integrating main, preserve the queued dependency in your task metadata and continue the existing scope. If a provider/hardware gate prevents full acceptance, retain the successor in waiting state and report the specific prerequisite; do independent current-stage work where possible.

## Runtime and recovery

`orchestrator.sequencing` provides inspection, transactional reservation and idempotent PID confirmation using the existing Store. Launch is journaled BEFORE the side effect. A reserved or uncertain launch is never automatically retried. Reconcile its `tool_operations` entry, local state, PID and receipt first. Cancellation or another unfinished dependency prevents release.

`scripts/sequential_cli_handoff.py` is a one-shot local task dispatcher. Its protected configuration, lock, PID, state and event logs reside outside Git under the owner's existing Codex temporary runtime. It watches the current CLI and checks the durable server gate after the current writer exits. It is not an autodeploy service, server installer, Telegram poller or store-publishing job. It stops after starting its one successor. While the Mac is asleep/offline, dispatch waits until its existing local runtime is available again; it does not pretend to be a continuously available cloud agent.

If restarting the dispatcher, preserve its config, operation ID and marker. An existing launch marker requires reconciliation; do not delete it to force a retry. A missing/invalid brief, lost SSH connection or unfinished predecessor must not start stage 3. Tests cover dependency states, all-parent gating, concurrent reservation, duplicate/unknown launches, cancellation, active writers, file tampering and a lost confirmation reply.

## Stage-3 scope and retained limits

The queued scope includes 400+ playable scenarios/variants, co-op, campaigns, persistent progression, clubs, world events and a path to multiple authoritative game processes. 100,000+ CCU is an architecture goal until real distributed tests prove capacity. Keep the existing 16-player per-instance limit until measured otherwise. No Kubernetes/Agones installation, paid resources, in-game payments or new store publication is authorized by queueing this brief. Existing finite paid-call limits, GPU ownership, data protection and disk reserves continue to apply. Use the existing coordinator/outbox for grouped milestone reports.
