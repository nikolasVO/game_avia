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
