# Measured Godot 4.7.2 ENet bandwidth defect

Pinned standard build: `4.7.2.stable.official.ed1daf0bf`. This does not change engines.

In the [exact upstream source](https://github.com/godotengine/godot/blob/4.7.2-stable/modules/enet/enet_multiplayer_peer.cpp#L62), `create_server` passes zero as max_channels and `p_max_channels + SYSCH_MAX` as incoming bandwidth to `create_host_bound`. Our intended three application channels became six bytes/second. Client statistics showed packet throttle limit1/32, missing unreliable command probes and sparse ordinary input receipt. Configuring RTT throttle alone did not fix the bandwidth limit. No absent packet was called rejected.

Immediately after create_server, explicitly set `peer.host.bandwidth_limit(0,0)` and `peer.host.channel_limit(6)`. ENet's ordinary congestion policy remains enabled. Application command rate/validation and fixed30Hz authority remain unchanged. After this fix, the same real client reported32/32 and all six distinct command probes arrived and were rejected by the production handler. A bogus admission ticket was separately observed/rejected; replay and expired-ticket events are recorded without tokens. The observer is attached only in the test scene; it replaces no RPC/validation logic. See `continuation-packet-before-fix.json` (FAIL retained) and `continuation-packet-fixed.json` (PASS).

This changes real input traffic, so the prior load result is not promoted to sustained-input capacity. Repeat the native16-client31-minute run with both snapshot delivery and accepted-input rate, retaining previous-source evidence separately.
