<p align="center">
  <img src="assets/paraware-logo.png" alt="Paraware PW logo" width="160">
</p>

# Paraware

A Roblox client hub built with [WindUI](https://github.com/Footagesus/WindUI). Paraware detects the current game and provides movement, flight, camera, lighting, and object-export controls in a wide window with a compact left sidebar.

## Features

- Walk speed, jump power/height, infinite jump, and noclip.
- Flight with keyboard and touch controls.
- Field of view, reset camera, and fullbright.
- Click/tap a loaded object to export a binary `.rbxm` model.
- Per-game module registry with universal fallback.
- Respawn handling, restore controls, session log, and cleanup on unload.
- PW branding on the top left, window controls on the right, and the actual game icon beside its name.

## Run

Open the root `Paraware.lua` and run its contents in your Roblox client runtime. It requires `loadstring` and `game:HttpGet`. Press **Right Shift** to show/hide the hub and **F** to toggle flight.

After uploading this repository, replace `YOUR_USERNAME` and `YOUR_REPOSITORY` in this example with your GitHub details. The example assumes your branch is `main`:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPOSITORY/main/Paraware.lua"))()
```

This URL is a template, not a published Paraware endpoint. Loading from `main` follows repository updates. Replace `main` with a commit ID if you want a fixed revision.

The PW logo uses `rbxassetid://101729681688072`. The original PNG is also embedded for the optional local-file route. This is a client-runtime script, not a drop-in Studio LocalScript.

## Export models

Select **Object export**, turn on **Object picker**, choose **Nearest model** or **Clicked part**, then click or tap an object outside the hub. The status shows the saved path or an error.

Files go to `Paraware-Exports/` in the runtime's workspace, or the workspace root if folders are unavailable. Export requires `writefile`. Use it for objects you own or have permission to export. It saves loaded client objects, excluding script instances and bytecode. Terrain and server-only objects are unavailable; underlying mesh/texture references can still require access to their Roblox assets.

See [the usage guide](docs/USAGE.md) for controls, logo options, and game-module examples.

## Edit and check

Edit `src/Paraware.lua`, then rebuild the root release:

```sh
python3 tools/build.py
npm ci
npm run check:build
npm test
```

Node.js 22 or newer is used for the checks. Python 3 bundles the source and original logo; neither is needed to run the already-built script. Commit both the source change and the rebuilt `Paraware.lua`.

The [GitHub Actions workflow](.github/workflows/check.yml) runs the build consistency check and mocked runtime tests on pushes and pull requests, using GitHub's [checkout](https://github.com/actions/checkout) and [setup-node](https://github.com/actions/setup-node) actions. Test dependencies are development-only and never load in Roblox.

## Repository files

| Path | Purpose |
| --- | --- |
| `Paraware.lua` | Built single-file script for users and raw GitHub loading |
| `src/Paraware.lua` | Editable source without the large embedded-image block |
| `assets/paraware-logo.png` | Original PW artwork |
| `tools/build.py` | Reproducible bundle generator |
| `tests/` | Mock Roblox services and runtime checks |
| `docs/USAGE.md` | Setup, controls, exports, and extension guide |
| `docs/VERIFICATION.md` | Test evidence and verification limits |
| `licenses/` | Unmodified third-party license texts |

## Upload to GitHub

Create an empty GitHub repository and upload this folder's contents to the repository root. Include the hidden `.github`, `.gitignore`, and `.gitattributes` entries. On Mac, **Command Shift .** shows hidden files in Finder. Keep `Paraware.lua` at the root so the loader example resolves correctly.

You can also use GitHub Desktop to add the prepared local repository, create its first commit, and publish it. No remote repository, account, or public upload is configured in this package.

## Credits and licenses

- [WindUI](https://github.com/Footagesus/WindUI), by Footagesus. Pinned build: `7dd8a34a6bb59635c7b5f18ce9d46558a8cde138`. Its MIT license is in [licenses/WindUI-MIT.txt](licenses/WindUI-MIT.txt).
- **UniversalSynSaveInstance https://discord.gg/wx4ThpAsmw**. Pinned exporter: `a6c93592f03791e6971261ee5586fba0a367b4b4`. Its full license and additional attribution terms are in [licenses/USSI-LICENSE.txt](licenses/USSI-LICENSE.txt). [Source](https://github.com/luau/UniversalSynSaveInstance/tree/a6c93592f03791e6971261ee5586fba0a367b4b4).
- The PW artwork was supplied for Paraware.

Third-party license notices do not assign a license to the original Paraware code or artwork. The repository owner can select those terms separately.

## Verification

Lua syntax, embedded-image integrity, and mocked behavior checks pass. The tests exercise movement modes, flight state, camera replacement, lighting restore, picker/export callbacks, module failures, respawns, repeated launches, and unload.

Mocks do not establish live Roblox physics, complete keyboard accessibility, actual serializer behavior, model import, or support in every executor/game. Server or game scripts may override local changes. See [verification details](docs/VERIFICATION.md).
