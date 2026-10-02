# Paraware Glass

A single Roblox client script using [WindUI](https://github.com/Footagesus/WindUI), with a wider frosted window, left sidebar, monochrome controls, a subtle glossy rim, and your PW logo.

The desktop window opens at 920 × 600, with a 180px sidebar and more room for controls. Smaller viewports reduce the initial dimensions to fit; narrower windows use a 125px sidebar. The window remains resizable up to 1120 × 800. Only three navigation items appear: Controls, Object export, and Session. Movement, flight, and camera controls remain grouped together on Controls.

The PW logo and Paraware title appear on the top left. Window controls appear on the top right using WindUI's native layout. The game information card displays the current experience's actual icon through Roblox's [GameIcon thumbnail format](https://create.roblox.com/docs/projects/assets), using its universe ID; it no longer repeats the PW logo there. If no published universe ID is available, the card shows the game information without an icon.

## Run it

1. Download the repository or its release package.
2. Open `Paraware.lua`, copy its contents into your Roblox client script runtime, and run it.
3. The logo is already configured as `rbxassetid://101729681688072`. No separate logo file is needed for that asset.
4. Press **Right Shift** to hide/show the hub. The draggable **Paraware** button also reopens it.

This version expects a client runtime that provides `loadstring` and `game:HttpGet`. It is not a drop-in Roblox Studio LocalScript. It downloads a pinned WindUI build from GitHub when launched. Some WindUI assets still come from upstream sources. Clipboard buttons additionally require `setclipboard` and show a message when it is unavailable.

If Roblox cannot serve that image to your runtime, clear `Config.LogoAsset` to `""`. The script then writes its embedded copy of your original PNG and loads it with `getcustomasset` or `getsynasset`. This fallback needs `writefile`; otherwise put the included PNG in your executor's workspace. If custom images are unavailable, a visible PW text mark appears. The original PNG is embedded unchanged.

## Controls

| Area | Features |
| --- | --- |
| Header | Actual game name, place/universe IDs, character status, PW logo |
| Movement | Walk speed, jump power, jump height, infinite jump, noclip |
| Flight | Fly, speed, rise, hold altitude, descend, stop flight |
| Camera & world | Field of view, reset camera to player, fullbright |
| Object export | Click/tap picker, model/part selection, binary .rbxm save status |
| Session | Last 12 events, copy/clear log, copy game IDs, restore all, unload |

Movement starts expanded in Controls. Tap Flight or Camera & world to expand those sections. Choose Object export or Session in the left sidebar to open those pages. A game-specific section appears inside Controls only when a module is registered.

## Click-to-export models

1. Select **Object export** in the left sidebar.
2. Turn on **Object picker**.
3. Select **Nearest model** to save the clicked part's nearest Model and its descendants, or **Clicked part** to save that part and its descendants.
4. Click or tap a loaded object outside the hub. Mouse hover outlines the prospective selection.
5. The status reports **Model saved** with the exact path, or **Export failed** with the error.

Files go to `Paraware-Exports/` in the executor's workspace when folder creation is supported. Otherwise they use a `Paraware-` filename prefix in the workspace root. This is a file written by the runtime, not an operating-system browser download. Names include a timestamp and counter. The script checks existing paths when `isfile` is available.

The exporter uses the binary model mode of [UniversalSynSaveInstance](https://luau.github.io/UniversalSynSaveInstance/api/SynSaveInstance/), pinned to `a6c93592f03791e6971261ee5586fba0a367b4b4`. It is loaded only when the first export starts. The result is a binary `.rbxm`, not XML with a renamed extension. The returned header is checked, and file existence/length/header are checked when the runtime supplies `isfile` and `readfile`.

Use this for objects you own or have permission to export. Only objects currently available to the client can be saved. Terrain is excluded. Script instances and bytecode are excluded. Mesh and texture references can still require access to their underlying Roblox assets; the model file does not grant access to private assets or server-only data. Export compatibility depends on the runtime and upstream serializer. The hub reports unsupported or empty output instead of falsely reporting a successful save.

Exporter credit: **UniversalSynSaveInstance https://discord.gg/wx4ThpAsmw**. Its license is included in [licenses/USSI-LICENSE.txt](../licenses/USSI-LICENSE.txt); the [upstream source](https://github.com/luau/UniversalSynSaveInstance/tree/a6c93592f03791e6971261ee5586fba0a367b4b4) is available publicly.

Sliders set the desired value; their associated toggle applies it. Jump controls respect the game's `Humanoid.UseJumpPower` mode. They do not force the game to use a different mode.

**Flight:** F toggles it. WASD or the mobile thumbstick moves horizontally. E or Space rises; Q or Left Ctrl descends. On touch devices, use Rise/Descend followed by Hold altitude. Switching away from the Roblox window clears the touch altitude command and stops movement until focus returns. Typing also stops flight movement and blocks the F shortcut.

Flight temporarily disables collisions, even when the separate Noclip toggle is off. Leaving flight restores them unless Noclip remains on. It uses `LinearVelocity` and `AlignOrientation` rather than deprecated body movers.

Enabled movement settings apply to each new standard character. Each respawn captures its own original values. Turning controls off or unloading restores captured values, destroys flight constraints, and disconnects listeners. Restore all disables controls but leaves slider choices in place. Hiding the window keeps features running; use Restore all or Unload to stop them.

Game scripts and the server can override local values. Custom rigs, vehicles, custom movement systems, and custom lighting may need their own modules. Fullbright changes basic Lighting properties locally; it does not remove Atmosphere or post-processing effects. Reset camera is a deliberate one-time action and is not reversed by Restore all.

## Game detection and extensions

Detection uses `game.PlaceId` and `game.GameId`, with a place module taking priority over a universe module. The displayed game name comes from MarketplaceService; if that lookup fails, ID detection still works.

**No game-specific modules are included.** Universal features are available immediately. To add your own module, insert an entry after `local GameModules = ...` near the top of the same file:

```lua
GameModules.Places[YOUR_PLACE_ID] = {
    Name = "Your game",
    Build = function(context)
        context.Tab:Button({
            Title = "Copy this place ID",
            Callback = function()
                if setclipboard then
                    setclipboard(tostring(context.PlaceId))
                    context.Log("Place ID copied.")
                else
                    context.Log("Clipboard unavailable.")
                end
            end,
        })
    end,
}
```

Replace `YOUR_PLACE_ID` with the game's numeric place ID. For all places in an experience, use `GameModules.Universes[YOUR_UNIVERSE_ID]` instead. These are authoring examples, not built-in game support.

The context includes `Window`, `WindUI`, `Tab`, `Player`, `Log`, `Connect`, `OnCleanup`, `PlaceId`, and `UniverseId`. Use `context.Connect(signal, callback)` for listeners so they disconnect when unloading. Register additional cleanup with `context.OnCleanup(function() ... end)`. A module error appears in Console and does not prevent the universal tabs from loading.

## Verification

Lua syntax and mocked runtime checks passed. Those checks cover the hub's callbacks and lifecycle behavior, not actual Roblox rendering, network behavior, executor compatibility, or physical movement. See `VERIFICATION.md` for evidence and remaining live checks.

WindUI build: `7dd8a34a6bb59635c7b5f18ce9d46558a8cde138`. Paraware's session log records hub events. It does not implement the executor's code editor or console interception.
