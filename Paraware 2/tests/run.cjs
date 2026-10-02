const fs = require('fs');
const luaparse = require('luaparse');
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require('fengari');
const source = fs.readFileSync('Paraware.lua','utf8');
luaparse.parse(source, {luaVersion:'5.3'});
console.log('PASS: Lua syntax');
const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);
function run(code) {
 if (lauxlib.luaL_loadstring(L,to_luastring(code)) !== lua.LUA_OK || lua.lua_pcall(L,0,lua.LUA_MULTRET,0) !== lua.LUA_OK) {
  throw new Error(to_jsstring(lua.lua_tostring(L,-1)));
 }
}
run(fs.readFileSync('tests/mock.lua','utf8'));
run(source);
run('assert(windows[1].config.Icon == "rbxassetid://101729681688072"); print("PASS: supplied logo ID uses the correct Roblox asset URI")');
run(source.replace('LogoAsset = "rbxassetid://101729681688072"', 'LogoAsset = ""'));
lua.lua_getglobal(L, to_luastring('files'));
lua.lua_getfield(L, -1, to_luastring('paraware-logo.png'));
if (!Buffer.from(lua.lua_tolstring(L, -1)).equals(fs.readFileSync('assets/paraware-logo.png'))) throw new Error('Embedded logo mismatch');
lua.lua_pop(L, 2);
console.log('PASS: embedded logo restores the original PNG byte for byte');
run('windows = {windows[#windows]}');
run(fs.readFileSync('tests/tests.lua','utf8'));
run(source);
run('assert(firstWindow.Destroyed); assert(#windows == 2); assert(_G.ParawareSession.Alive); print("PASS: rerun unloads the previous session")');
run('click("Settings/Unload Paraware"); assert(_G.ParawareSession == nil); assert(player.Character.H.WalkSpeed == 18); for _, c in ipairs(runservice.PreSimulation.connections) do assert(not c.Connected) end; print("PASS: unload restores defaults and disconnects listeners")');
run(source.replace('local GameModules = { Places = {}, Universes = {} }', `local GameModules = {
 Places = {[123] = {Name = "Place module", Build = function(ctx)
  assert(ctx.PlaceId == 123 and ctx.UniverseId == 456)
  ctx.OnCleanup(function() moduleCleaned = true end)
  error("deliberate module test error")
 end}},
 Universes = {[456] = {Name = "Universe module", Build = function() error("wrong module selected") end}}
}`));
run('assert(control("Game/Place module")); assert(control("Game/Module failed")); click("Player/Custom speed", true); assert(player.Character.H.WalkSpeed == 32); click("Settings/Unload Paraware"); assert(moduleCleaned); print("PASS: place registry precedence, isolated module failure, module cleanup")');
