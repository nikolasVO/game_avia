# Automatic recovery of the external implementation agent

Owner instruction, 17 November 2026: interruptions such as an unfinished operation and an exhausted model allowance should be handled without asking the owner to restart work.

The development CLI actually exited with `turn.failed`: usage limit reached. Its rollout contained the structured `codex` weekly window at 100% and `resets_at=1795093789`. This is a real account allowance, not a game/network failure. Automatic recovery waits until that reset plus 90 seconds. It does not buy credits, switch to an unverified provider or reopen the closed paid bootstrap.

The previously outstanding `development-464-release-v1` is a `github_prerelease` operation for `game-avia-development-p1-20261117-r3`. Recovery checks repository access and both release/tag metadata. Two authenticated/local checks found neither release nor tag. The automatic public-API reconciliation independently verifies this before recording `not_published`. Recording a resolved journal outcome is not publishing a build or accepting the development task. A later publication must use a new operation identity and validate actual artifacts.

## Runtime

`scripts/cli_recovery_watchdog.py` is a local persistent task controller, with a protected config, lock, state, checkpoint and event files outside Git. It observes the existing implementation process metadata, so the same controller can follow the accepted transition to stage 3. It does not interrupt a running agent, claim completion, deploy application code, install infrastructure or create another Telegram consumer.

- While the exact CLI session/worktree has a live writer, renew its owned task lease. Do not extend a task owned by another process.
- After the writer exits, inspect the task and unfinished operations. `orchestrator.recovery` automatically resolves only supported publication operations with sufficient GitHub evidence. Inaccessible repositories, mismatched commit/digests, partial uploads and unknown effect types retain their journal entries.
- Wait for authoritative quota resets. Transient failures use bounded backoff. Authentication problems use a longer delay. Repeated waiting states do not produce duplicate owner notifications.
- At retry, hold the same writer lock used by the stage dispatcher, recheck local processes and atomically reserve the same task. Preserve the same CLI session, working tree, original brief and unfinished files. Journal launch before spawning; a lost confirmation retries only the same PID.
- Preserve explicit pause/cancellation, terminal task states and all predecessor/acceptance gates. Full task acceptance never follows from recovery, a successful publication or a CLI exit.
- Keep previous progress in private Store KV `recovery_last_progress:<task_id>`. The task's visible result explains the actual recovery reason and retry time. Progress artifacts and unknown operations are not removed.

The deployed controller runs detached in the same already-authorized application context as the working game CLI. An actual user LaunchAgent probe was denied access to the project under macOS Documents privacy protection; the failed service and its plist were removed. Do not claim reboot/login persistence or request broad disk access as a routine fix. The existing detached runtime works while the Mac and network remain available; after a reboot it must be started by an authorized application context. Existing game/Point services and GPU workloads are not restarted. No deployment timer, webhook, GitHub Action or billing automation is enabled.

Quota and access restrictions remain external conditions: recovery waits and resumes when they permit, rather than pretending that inference continues during an exhausted allowance. Unsupported uncertain effects remain protected until there is evidence sufficient to reconcile them. Logs and reports explain these states; automatic retries do not invent successful outcomes.

## Validation

Tests cover quota-reset scheduling, bounded retries, inaccessible GitHub endpoints, matching release commit/hash proofs, genuinely absent publication, uncertain effects, duplicate launch/confirmation, explicit stops, dependency gates and deduplicated notifications. Live installation must additionally verify the protected waiting state, independent server reconciliation and active local controller. These checks do not prove a future quota reset or a new playable game milestone.
