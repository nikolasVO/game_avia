# Flight server operations

The game server is a separate s6/supervisor service **game-avia-flight**, owned by ubuntu. It is not the API/coordinator/executor and contains no Telegram poller or LLM request path. The original services remain at their previous deployment SHA and were not restarted for this game deployment.

Current game binary/source: `3417828170d35a3ab2acac0c3fc1ad5ab2bf1046`, binary SHA256 `5b884ac8ceae4c26821403c815a9361fed5afd6b8746a9fefbbcbc7840c01346`. Location `/srv/game-avia/releases/<SHA>/game-avia-server.x86_64`; UDP24567, protocol3 ENet/DTLS. External mapping is BLOCKED, despite working loopback sessions. Logs `/srv/game-avia/logs/flight.log` rotate5MB +3 backups; stats `/srv/game-avia/state/flight/progress.json` are atomically replaced. Server private key and supervisor socket/config remain protected in that directory.

From an authorized SSH session:

```sh
/srv/game-avia/venvs/core/bin/supervisorctl -c /srv/game-avia/state/flight/supervisord.conf status
tail -n 30 /srv/game-avia/logs/flight.log
ss -ulnp
```

`server_ready` plus live `health` tick/connection counters establish process progress. A listening socket is not external reachability. Run two actual protocol clients after every update. The post-deploy protocol3 smoke passed. Anonymous confirmed totals survive restart; race fixture restoration preserved2 finishes and48.5s best.

Manual update only: commit/push and verify remote SHA, export from a clean checkout using exact templates, verify binary SHA on both hosts, retain>=10GiB disk reserve (39GiB observed), journal the operation through the existing Store, copy into a new immutable release directory, save validated progress JSON backup, replace only the flight config release path, then supervisor `reread` and `update`. Verify process owner, health, deployed SHA, two clients and original service PIDs. The supplied `server/supervisord-flight.conf` is a template; `server/s6-flight-run` uses the host's `/command/s6-setuidgid`. No timer/webhook/Action updates it.

Rollback: use the preserved previous release `794e331e172f15e50b716ac8e9ac150e9dc54c9b` (protocol2) and a matching client. Journal rollback, select the prior path in the flight supervisor config, reread/update, verify health and progress. Do not restore older aggregate stats over new confirmed totals unless explicitly intended. Do not restart game-avia coordinator/API or stop Point/unknown services for a flight rollback.

Recovery after interruption: inspect exact release path, process command line, binary hash and operation journal before repeating a deployment. A lost SSH session does not imply the remote command failed. This occurred during the native load run: existing report/logs were reconciled after reconnect; no second31-minute run was claimed.

The31-minute native-binary test used a separate bounded server on UDP24588,16 active clients for1860s and a conservative1850s interval at16 connections. Its CPU/RSS and health evidence are in `docs/evidence/native-load16-3417828.json`. Test processes have exited. Known DTLS shutdown error -30464 is recorded; one interleaved stderr/stdout line originally made the strict harness fail and was correctly reclassified without altering measurements.

Backups: coordinator uses SQLite backup API, AES-GCM off-server export and separate restore/integrity check. The newest confirmed snapshot restored20 tasks on the owner's Mac. The encryption key is outside Git. Flight progress has a protected pre-upgrade snapshot under `/srv/game-avia/state/flight/backups/`. No operational DB or private key is a release artifact.
