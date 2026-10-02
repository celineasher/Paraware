# Verification

The built `Paraware.lua` is generated deterministically from `src/Paraware.lua` and the supplied original PNG. `tools/build.py --check` verifies those inputs match the committed release.

The root release is parsed as Lua-compatible syntax with luaparse and executed in Fengari with mock Roblox services and mock WindUI. The checks invoke the real Paraware callbacks. They do not render the GUI or simulate Roblox physics.

Passing checks cover:

- Correct supplied logo URI and byte-for-byte embedded PNG integrity.
- Three sidebar destinations, default selection, desktop dimensions, and right-side topbar configuration.
- Game thumbnail URI built from the actual universe ID.
- Speed, both jump modes, infinite jump, and collision restoration.
- Flight constraint lifecycle, vertical input, speed normalization, typing/focus guards, and hotkey handling.
- FOV across camera replacement, camera reset, and lighting restoration.
- Copy/clear log and copy game IDs.
- Mouse/touch picker, model/part scope, binary-output callback contract, and failure states.
- Respawn rebinding, restoring each character's captured defaults, repeat launch, and unload.
- Registry precedence, isolated module failure, and module cleanup.

The exporter test supplies a mock payload with a Roblox binary header. It validates Paraware's serializer integration contract and file checks, not a real USSI serialization or Studio import. Live rendering, thumbnail delivery, physical flight, exported model completeness, and executor compatibility need checks in Roblox.

Delivery review: PASS for the inspected scope. Navigation targets exist; authored controls have callbacks; runtime data and failures are labeled; no game-specific support or live compatibility claims are fabricated. The repository contains source, logo, reproducible build, tests, documentation, and preserved third-party license notices. Temporary dependencies, local model exports, and machine-specific paths are excluded from the upload archive.
