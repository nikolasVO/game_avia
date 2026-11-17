# Operation and recovery

The inspected host uses s6, not systemd. Existing Ubuntu, CUDA 12.4, torch 2.6.0+cu124, Python 3.12 core / Python 3.10 TRELLIS, Blender 5.2.4 and source checkouts are reused. Do not rerun the historical installer or alter Point services.

The deployed s6 entry is /etc/services.d/game-avia/run, also linked into /run/service/game-avia. Legacy s6 startup retains it across container restarts. It runs supervisord as ubuntu. The protected Unix control socket is in the runtime directory. Supervisor rotates each log at 5 MB with three backups. State and artifacts are private. Systemd unit files are provided for a future systemd host and are not active here.

From /srv/game-avia/repo:

    /srv/game-avia/venvs/core/bin/supervisorctl -c deploy/supervisord.conf status
    /srv/game-avia/venvs/core/bin/python -m scripts.doctor
    /srv/game-avia/venvs/core/bin/python -m scripts.backup_restore_check
    /srv/game-avia/venvs/core/bin/python -m scripts.sandbox_probe
    /srv/game-avia/venvs/core/bin/python -m pytest -q

The API listens only on 127.0.0.1:8787. Health is unauthenticated and contains no secret. All task/asset routes require the bearer token from the private environment file. Task input has no recipient field. Do not expose the API publicly.

Update manually: preserve a local SQLite backup, confirm clean checkout and origin/main, pull --ff-only, install using the project lock, run tests and doctor, then restart this project's s6 service. Check health release SHA and the environment SHA of all three runtime children. No GitHub Action, deploy timer, webhook or push-triggered publication is configured. Other services are outside this release.

Telegram has one coordinator process, protected by flock. It accepts only the pinned owner's private chat. /pause prevents new execution; /cancel <id> withdraws the current task at a checked boundary. /resume enables available queued tasks. Commands include /status /tasks /task /models /providers /gpu /disk /assets /budget /report. The budget command reports reserved token counts separately from money. A large backlog is blocked without a monetary budget. The bootstrap cap is 12 text requests and one image generation; it must not be silently raised.

SQLite changes to tasks, events and notification outbox are transactional. Incoming update IDs and command effects are atomic. Confirmed transient send failures retry with backoff. A send with unknown outcome remains unknown and is not automatically resent. A process crash during sending becomes unknown on restart. Telegram cannot guarantee exactly-once delivery. Inspect unknown entries before an explicit resend decision.

Tasks keep worktrees and journals. Expired execution with a started operation becomes blocked for reconciliation. Confirmed tool-call IDs cannot be reused with different arguments. File/test read caching includes a source snapshot. A cancelled/stale task cannot start further tools. GitHub sync checks the exact remote branch SHA before accepting success; no force-push is used.

The automatic executor writes only inside the worktree's game/ subtree. Test code runs in a read-only bubblewrap namespace with no network, no host home/configuration, a private PID namespace, bounded CPU/address-space/process/file/output limits and a trusted unittest harness mounted outside generated code. Temporary-file and subprocess-heavy tests may require a separately designed sandbox profile. Docker proot could not provide --network none and is not used as a weaker fallback.

A successful bounded code task requires at least one passing isolated test, independent review, commit, push and remote SHA confirmation. Reviewed task branches remain separate until the single integrator accepts them. A model's completion claim never suffices. The bootstrap technical task required integrator recovery of its test harness; unattended end-to-end operation is not asserted.

GPU ownership includes a SQLite fencing lease and a live process guard. A subprocess is killed before its lease is released on loss of ownership. A shared Ollama request leaves a persistent busy marker until model unload is confirmed. If that process crashes, reconcile /api/ps before clearing the marker; never reset it merely because a lease expired. Point GPU services retain their current owners. New large work stops below a 10 GiB disk reserve.

Local backup uses SQLite backup and validates integrity after restore. Off-server encrypted exports are stored on the owner's Mac with the encryption key outside Git. They are milestone snapshots, not a continuous remote backup service. Never copy a live SQLite file without WAL/backup handling.

Rollback: keep the prior commit, virtualenv lock and private environment backup. Stop the executor, back up state, select the prior verified checkout and restart only game-avia. Do not replace private configuration or restore an old DB over new state without reviewing the task/outbox journal.

