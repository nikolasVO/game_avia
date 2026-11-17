# Game server operations — current P1 prototype

Current deployed flight source `5c0df281c459fd98f4a75a5a7d59a96c8814ff61`, binary SHA256 `b10ec315f6f4b88e6cdf225dbe09104dd5ad1cb70ce4a6739242ed17e590eca4`, protocol4/UDP24567. Manual update and actual rollback5c→c192→5c passed two matching real clients at each phase. Aggregate progress116→120→122→124 was preserved; increments are explicitly identified smoke bots, not human career statistics. [Evidence](evidence/deployment-5c0df28.json). Full development acceptance remains incomplete and external UDP is still FAIL.

The flight service is separate from API/coordinator/executor and has no Telegram/LLM path. Only supervisor program `flight` was updated. Protected config/key/progress remain under `/srv/game-avia/state/flight/`; release binaries under `/srv/game-avia/releases/<sourceSHA>/`. Core and Point were not restarted. `main` integrated the tested game milestone atd3c3f31; running binary source is independently5c0df28.

Health/diagnostics from the existing authorized SSH session:

```sh
/srv/game-avia/venvs/core/bin/supervisorctl -c /srv/game-avia/state/flight/supervisord.conf status flight
/srv/game-avia/venvs/core/bin/supervisorctl -c /srv/game-avia/state/flight/supervisord.conf pid flight
tail -n 20 /srv/game-avia/logs/flight.log
ss -ulnp
```

The manual launch now uses `/usr/bin/stdbuf -oL -eL` so native stdout/stderr are visible promptly. A real finite test observed `server_ready` at0.191s with line buffering, versus3.241s at process exit without it. `STARTING` immediately after `update` is expected: wait for the actual PID/executable hash and fresh `server_ready`/protocol, then connect two clients. Never repeat a restart merely because an immediate status parse lacks a PID. A listening socket and SSH TCP connectivity do not prove external UDP.

Manual update procedure: verify pushed source/LFS and clean matching client/server exports; keep≥10GiB server disk reserve; journal intent through existing Store; verify old process/config and empty session; copy/hash new immutable release; snapshot consistent progress/config into protected backup; atomically change only flight release path; run supervisor `reread`, then `update flight`; poll actual PID/hash/fresh protocol; test two matching clients. Preserve totals and do not copy synthetic load-test progress into production. There are no deployment timers/Actions/webhooks.

Rollback was actually exercised to `c1922c74a29112818ce9ee523a9cdc81eb211180`, binary SHA256 `f6b1aea7fc5790e538d75eeafd69a0361cdd9013249208242be05fb8c2e1ed63`, protocol3. Keep current confirmed progress, select retained old release/config path, reread/update only flight, and use old matching clients to verify. The run preserved120 flights, old-client smoke added2, and return to5c preserved122 before final smoke added2. Protected snapshots: `state/flight/backups/manual-5c0df28-20261117-pre-update`, `-pre-rollback`, `-pre-return`. Do not restore older totals over new results or publish protected snapshots.

After interruption inspect current config, actual `/proc/<flightPID>/exe` hash, command line, health, operation journal and artifacts before repeating any action. Current development task68c406f99772 remains running and its primary lease is maintained only while the exact owner CLI process is active. A manual status/handoff is not full task completion.

Current test downloads: [P1 prerelease](https://github.com/nikolasVO/game_avia/releases/tag/game-avia-development-p1-20261117-r1), [source/hash manifests](evidence/artifact-index-p1.json). Historical operational evidence follows with its original scope.

---

# Flight server operations

The game server is a separate s6/supervisor service **game-avia-flight**, owned by ubuntu. It is not the API/coordinator/executor and contains no Telegram poller or LLM request path. The original services remain at their previous deployment SHA and were not restarted for this game deployment.

Current game binary/source: `c1922c74a29112818ce9ee523a9cdc81eb211180`, binary SHA256 `f6b1aea7fc5790e538d75eeafd69a0361cdd9013249208242be05fb8c2e1ed63`. Location `/srv/game-avia/releases/<SHA>/game-avia-server.x86_64`; UDP24567, protocol3 ENet/DTLS. External mapping is BLOCKED, despite working loopback sessions. Logs `/srv/game-avia/logs/flight.log` rotate5MB +3 backups; stats `/srv/game-avia/state/flight/progress.json` are atomically replaced. Server private key and supervisor socket/config remain protected in that directory.

From an authorized SSH session:

```sh
/srv/game-avia/venvs/core/bin/supervisorctl -c /srv/game-avia/state/flight/supervisord.conf status
tail -n 30 /srv/game-avia/logs/flight.log
ss -ulnp
```

`server_ready` plus live `health` tick/connection counters establish process progress. A listening socket is not external reachability. Run two actual protocol clients after every update. The c192 post-deploy two-client smoke passed; progress114→116 flights was preserved across this update. Anonymous confirmed totals survive restart; race fixture restoration preserved2 finishes and48.5s best.

Manual update only: commit/push and verify remote SHA, export from a clean checkout using exact templates, verify binary SHA on both hosts, retain>=10GiB disk reserve (39GiB observed), journal the operation through the existing Store, copy into a new immutable release directory, save validated progress JSON backup, replace only the flight config release path, then supervisor `reread` and `update`. Verify process owner, health, deployed SHA, two clients and original service PIDs. The supplied `server/supervisord-flight.conf` is a template; `server/s6-flight-run` uses the host's `/command/s6-setuidgid`. No timer/webhook/Action updates it.

Rollback: preserve current progress and select the tested `9412be74cb37b9cb028d260acca12692cdae265a` binary (protocol3, identical authority code, full native load evidence), then reread/update only flight and verify two clients. The prior deployed3417828 and older794e331 protocol2 remain stored;341 has the known bandwidth defect and794 requires its matching client. Do not restore older totals over confirmed new progress. Protected pre-c192 progress/config snapshots exist under state/flight/backups. Journal and reconcile before retrying any uncertain operation.

Recovery after interruption: inspect exact release path, process command line, binary hash and operation journal before repeating a deployment. A lost SSH session does not imply the remote command failed. This occurred during the native load run: existing report/logs were reconciled after reconnect; no second31-minute run was claimed.

The new31-minute native test used the exact9412 exported binary on24588:16 clients1850 continuous seconds,887989 accepted inputs (~30Hz each), max simulation-body p953.352ms, maxRSS92MiB/maxCPU8.197% of one core. `native-load16-9412be7.json`. c192 has byte-identical authority files and its actual binary separately passed native/post-deploy smoke; do not rewrite the measured source SHA. The old341 run is historical connection/snapshot evidence because the bandwidth defect starved input. Finite test processes exited. Known16 departure-time DTLS diagnostics remain recorded.

Backups: coordinator uses SQLite backup API, AES-GCM off-server export and separate restore/integrity check. The newest confirmed snapshot restored20 tasks on the owner's Mac. The encryption key is outside Git. Flight progress has a protected pre-upgrade snapshot under `/srv/game-avia/state/flight/backups/`. No operational DB or private key is a release artifact.
