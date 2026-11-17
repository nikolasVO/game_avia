# game_avia

Implement the owner's game-development environment specification dated 17 November 2026. Do not invent the game's genre or mechanics. Establish the environment and one real technical asset/build example first.

Use separate task branches and worktrees for independent agents; one integrator owns shared configuration and Unity scene/prefab/ProjectSettings changes. Preserve existing changes; never force-push. Commit and push verified milestones, with short Russian `Updates-Ru:` lines in commit bodies.

Secrets stay in protected environment files outside Git. Never include credentials, private chat IDs, operational databases, raw provider responses, model weights, caches or Unity Library in Git or reports. Worker environments contain only necessary credentials. Telegram recipients are pinned in private server configuration; only the owner's private chat may create tasks or receive reports.

Task state, events and notification outbox must commit atomically. Journal side effects before execution. After interruption reconcile unknown operations rather than repeating them. Preserve task identity and worktree across provider fallback. Keep capability evidence separate; a catalog or text response does not imply agent readiness.

Cloud calls require finite request/token/deadline limits; large autonomous backlog is blocked until monetary budgets are configured. Unknown price is `cost_unknown`. No subscriptions, balance refill, hosting plan changes or app-store publication without a separate instruction.

Use one GPU lease manager and a measured disk reserve. Never stop unknown hosting services or remove unrelated models/data. TRELLIS starts in the compact 512 profile with BiRefNet and gated DINOv3 access respected. Kev is disabled by default.

Read installed-version documentation and verify real behavior. Mocks test failures and races; they do not prove provider, Telegram, GPU inference or Unity builds. Report installed/configured/tested/blocked separately. Publish code, deployment SHA, tests, live outcomes and remaining blockers honestly.
