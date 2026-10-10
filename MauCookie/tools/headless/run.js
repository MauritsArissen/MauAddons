// Headless run of the MauCookie addon under fengari (Lua 5.3 in JS) with
// WoW API stubs: loads the files in TOC order, then runs scenario.lua.
const fs = require('fs');
const path = require('path');
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require('fengari');

const addonDir = path.resolve(__dirname, '..', '..');
const L = lauxlib.luaL_newstate();
lualib.luaL_openlibs(L);

function runChunk(src, name, args) {
  const status = lauxlib.luaL_loadbuffer(L, to_luastring(src), to_luastring(name));
  if (status !== lua.LUA_OK) {
    console.log('LOAD FAIL ' + name + ': ' + to_jsstring(lua.lua_tostring(L, -1)));
    process.exit(1);
  }
  let n = 0;
  if (args) {
    for (const a of args) {
      if (a === 'NS') lua.lua_getglobal(L, to_luastring('__NS'));
      else lua.lua_pushstring(L, to_luastring(a));
      n++;
    }
  }
  const base = lua.lua_gettop(L) - n;
  lua.lua_getglobal(L, to_luastring('__traceback'));
  lua.lua_insert(L, base);
  const st = lua.lua_pcall(L, n, 0, base);
  if (st !== lua.LUA_OK) {
    console.log('RUN FAIL ' + name + ': ' + to_jsstring(lua.lua_tostring(L, -1)));
    process.exit(1);
  }
  lua.lua_settop(L, base - 1);
}

runChunk('__traceback = function(msg) return debug.traceback(tostring(msg), 2) end; __NS = {}', 'init');

const toc = fs.readFileSync(path.join(addonDir, 'MauCookie.toc'), 'utf8');
const files = toc.split(/\r?\n/).filter(l => /^[A-Za-z_]+\.lua\s*$/.test(l)).map(l => l.trim());

// Method whitelist for the frame stubs: every ":Name(" in the addon sources.
const names = new Set();
for (const f of files) {
  for (const m of fs.readFileSync(path.join(addonDir, f), 'utf8').matchAll(/:([A-Z][A-Za-z0-9_]*)\(/g)) names.add(m[1]);
}
runChunk('__METHODS = {' + [...names].map(n => n + '=true').join(',') + '}', 'methods');
runChunk(fs.readFileSync(path.join(__dirname, 'stubs.lua'), 'utf8'), 'stubs.lua');

for (const f of files) {
  const src = fs.readFileSync(path.join(addonDir, f), 'utf8');
  runChunk(src, f, ['MauCookie', 'NS']);
}
console.log('loaded ' + files.length + ' files, ' + names.size + ' method names');
runChunk(fs.readFileSync(path.join(__dirname, 'scenario.lua'), 'utf8'), 'scenario.lua');
console.log('scenario finished');
