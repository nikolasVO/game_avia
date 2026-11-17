# Mac Unity proof runner

Unity Editor 6000.3.28f1, revision 8f082d2fe476, is installed at `~/Applications/Unity/6000.3.28f1/Unity.app`. Its Intel installer came from Unity's official release API, matched the published byte size and MD5, and had a trusted Apple installer signature from Unity Technologies SF (9QW8UQUTAA). The installed app passed deep strict codesign verification; `Unity -version` returned the pinned version. Hub 4.0.1 is installed at `~/Applications/Unity Hub.app`; its official SHA512 and app signature passed.

A real batchmode project-creation probe exited 198: `No valid Unity Editor license found. Please activate your license.` Sign in through Hub and activate the owner's eligible license. Account login/eligibility/terms require the owner. No subscription was purchased. Full Xcode and signing are absent; Android matching modules are not installed. No platform build is accepted.

The project at unity/AviaProof pins URP 17.3.0 (the Editor's bundled version) and Unity glTFast 6.15.1. Its Editor method imports the actual procedural fixture GLB, requires its measured 188 triangles, one material, metre bounds and bottom pivot, binds LODGroup and BoxCollider, and attempts a macOS development build. It never substitutes a Unity primitive for a failed GLB import. This C# code is prepared but remains uncompiled/unverified behind the license gate; scenes, prefabs, generated .meta and resolved package lock must be reviewed and committed after a successful licensed run. The fixture is not TRELLIS output.

From the owner's Mac, with its existing outbound SSH alias configured and unlocked:

    PATH="$HOME/.local/bin:$PATH" python3 -m scripts.mac_unity_runner --commit <full-deployed-SHA>

The runner accepts a full SHA, checks it against both the deployed server checkout through SSH and origin/main, and creates a detached private worktree. It verifies the LFS mesh hash, passes a filtered environment to Editor, serializes runs with flock and bounds execution to 15 minutes. A timed-out Editor process group is killed. Only the fixed proof method on reviewed main is executed; arbitrary task branches are not an execution interface. This is a manual runner, not an automatic job poller.

The real runner smoke at commit 65bbc98b36235e72b69525bf4954f3db1e8f38e8 passed SSH/deployed-SHA checks, detached worktree creation and LFS hash verification, then returned a structured blocked_license report (Editor exit 198) to the server. This verifies transport/orchestration, not C# compilation or a build. See reports/unity-runner-smoke.json.

Structured evidence returns through outbound SSH to `/srv/game-avia/artifacts/unity-<SHA>/report.json`. Raw Editor logs stay in the owner's private Mac cache, outside Git and Telegram. Generated output stays in the worktree/run directory for inspection; neither a zero process exit alone nor a model's claim accepts a build. Build success requires the Editor result and real .app output. A screenshot, launching the built player, Android/iOS builds and target-device measurements remain separate acceptance steps.

Sources: [official Editor release metadata](https://services.api.unity.com/unity/editor/release/v1/releases?limit=1&version=6000.3&platform=MAC_OS&architecture=X86_64), [URP for Unity 6.3](https://docs.unity.com/en-us/engine/6000.3/manual/render-pipelines/universal-render-pipeline/urp-introduction), [glTFast Editor import](https://docs.unity3d.com/Packages/com.unity.cloud.gltfast@6.15/manual/ImportEditor.html), [Hub license management](https://docs.unity.com/en-us/hub/manage-license).
