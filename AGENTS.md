# game_avia

The current owner implementation brief is docs/briefs/game-avia-20261117.md, preserved verbatim from the 17 November attachment. It now explicitly defines a native iOS/Android multiplayer flight game, its mechanics and version 0.1 acceptance. This supersedes the earlier environment-only instruction to wait for a game brief. Audit the existing work, then implement the real vertical slice. Godot stable is the primary candidate; verify it and record the engine decision before scaling content. The owner-activated Unity license probe now passes; it is infrastructure evidence, not an engine selection. Godot4.7.2 remains selected. Preserve the existing coordinator and useful tools. See docs/handoffs/implementation-20261117.md for verified state and limitations.

Use separate task branches and worktrees for independent agents; one integrator owns shared configuration and Unity scene/prefab/ProjectSettings changes. Preserve existing changes; never force-push. Commit and push verified milestones, with short Russian `Updates-Ru:` lines in commit bodies.

Secrets stay in protected environment files outside Git. Never include credentials, private chat IDs, operational databases, raw provider responses, model weights, caches or Unity Library in Git or reports. Worker environments contain only necessary credentials. Telegram recipients are pinned in private server configuration; only the owner's private chat may create tasks or receive reports.

Task state, events and notification outbox must commit atomically. Journal side effects before execution. After interruption reconcile unknown operations rather than repeating them. Preserve task identity and worktree across provider fallback. Keep capability evidence separate; a catalog or text response does not imply agent readiness.

Cloud calls require finite request/token/deadline limits; large autonomous backlog is blocked until monetary budgets are configured. Unknown price is `cost_unknown`. No subscriptions, balance refill, hosting plan changes or app-store publication without a separate instruction.

Use one GPU lease manager and a measured disk reserve. Never stop unknown hosting services or remove unrelated models/data. TRELLIS starts in the compact 512 profile with BiRefNet and gated DINOv3 access respected. Kev is disabled by default.

Read installed-version documentation and verify real behavior. Mocks test failures and races; they do not prove provider, Telegram, GPU inference or Unity builds. Report installed/configured/tested/blocked separately. Publish code, deployment SHA, tests, live outcomes and remaining blockers honestly.
