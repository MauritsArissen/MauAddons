// Runs Cookie Clicker's main.js under a stubbed browser until Game.Init()
// completes, then dumps the game's data tables to cc-data.json.
const fs = require('fs');
const vm = require('vm');
const src = fs.readFileSync("../cc-source/main.js", "utf8").split("Game.YouCustomizer.render();").join("");
const en = fs.readFileSync('../cc-source/EN.js', 'utf8');

function anything() {
  const fn = function () { return proxy; };
  const proxy = new Proxy(fn, {
    get(t, k) {
      if (k === Symbol.toPrimitive) return () => 0;
      if (k === 'toString') return () => '';
      if (k === 'valueOf') return () => 0;
      if (k === 'length') return 0;
      if (k === 'then') return undefined;
      if (k === Symbol.iterator) return function* () {};
      return proxy;
    },
    set() { return true; }, apply() { return proxy; }, construct() { return proxy; }, has() { return true; }, deleteProperty() { return true; },
  });
  return proxy;
}
const el = anything();
function Klass() { return el; }

const extra = { SAVESUFFIX: '' };
let G = null;
let sandbox = null;
for (let attempt = 0; attempt < 80; attempt++) {
  sandbox = {
    console: { log() {}, trace() {}, warn() {}, error() {} },
    setTimeout: () => 0, setInterval: () => 0, clearTimeout() {}, clearInterval() {},
    encodeURIComponent, decodeURIComponent, escape: s => s, unescape: s => s,
    document: el,
    localStorage: { getItem: () => null, setItem() {}, removeItem() {} },
    navigator: { userAgent: 'node', language: 'en', platform: 'Win32' },
    location: { href: 'https://orteil.dashnet.org/cookieclicker/', pathname: '/cookieclicker/', search: '', hash: '', hostname: 'orteil.dashnet.org' },
    Image: Klass, Audio: Klass, XMLHttpRequest: Klass, FileReader: Klass, Blob: Klass, Worker: Klass, Element: Klass, HTMLElement: Klass, Node: Klass,
    Event: Klass, CustomEvent: Klass, MouseEvent: Klass, KeyboardEvent: Klass, TouchEvent: Klass, CanvasRenderingContext2D: Klass, HTMLCanvasElement: Klass,
    AudioContext: Klass, webkitAudioContext: Klass,
    screen: { width: 1920, height: 1080 }, performance: { now: () => 0 }, requestAnimationFrame: () => 0, cancelAnimationFrame() {},
    history: el, innerWidth: 1920, innerHeight: 1080, devicePixelRatio: 1,
    alert() {}, confirm() { return false; }, prompt() { return ''; }, addEventListener() {}, removeEventListener() {}, getComputedStyle: () => el,
    atob: s => Buffer.from(s, 'base64').toString('binary'), btoa: s => Buffer.from(s, 'binary').toString('base64'),
    App: 0, VERSION: 2.052, BETA: 0, EN: true, PRESETMODS: [],
  };
  Object.assign(sandbox, extra);
  sandbox.window = sandbox; sandbox.self = sandbox; sandbox.globalThis = sandbox; sandbox.top = sandbox; sandbox.parent = sandbox;
  vm.createContext(sandbox);
  let stage = 'main.js';
  try {
    vm.runInContext(src, sandbox, { filename: 'main.js' });
    stage = 'EN.js';
    vm.runInContext(en, sandbox, { filename: 'EN.js' });
    sandbox.locStringsFallback = sandbox.locStrings;
    G = sandbox.Game;
    stage = "Launch";
    G.Launch();
    if (!G.Loader && typeof sandbox.Loader === "function") { G.Loader = new sandbox.Loader(); G.Loader.domain = "img/"; }
    if (G.Loader) { G.Loader.Load = function () {}; G.Loader.waitForLoad = function () {}; G.Loader.Replace = function () {}; G.Loader.assetsLoaded = []; }
    stage = "Init";
    try { G.Init(); } catch (e) { if (!/Game.(Loop|Draw|DrawBackground)/.test(e.stack)) throw e; console.log("Init reached the render loop (" + e.message + "), data is complete"); }
    console.log('Init completed after ' + (attempt + 1) + ' attempt(s); stubbed globals: ' + Object.keys(extra).join(', '));
    break;
  } catch (e) {
    const m = /^(\w+) is not defined/.exec(e.message);
    if (m) {
      extra[m[1]] = (m[1] === m[1].toUpperCase()) ? '' : el;
      continue;
    }
    console.log('stopped at ' + stage + ': ' + e.stack.split('\n').slice(0, 6).join('\n'));
    process.exit(1);
  }
}
if (!G || !G.Upgrades) { console.log('no data'); process.exit(1); }

const strip = s => (typeof s === 'string' ? s.replace(/<[^>]+>/g, '').replace(/\s+/g, ' ').trim() : s);
const quote = s => { const m = /<q>([\s\S]*?)<\/q>/.exec(String(s)); return m ? strip(m[1]) : ''; };
const noquote = s => strip(String(s).replace(/<q>[\s\S]*?<\/q>/g, ''));
const num = v => (typeof v === 'number' && isFinite(v)) ? v : (typeof v === 'function' ? null : (v === undefined ? null : v));

const out = { version: G.version, HCfactor: G.HCfactor, tiers: {}, buildings: [], upgrades: [], achievements: [], unlockAt: [], misc: {} };
for (const k in G.Tiers) {
  const t = G.Tiers[k];
  out.tiers[k] = { name: t.name, unlock: t.unlock, achievUnlock: t.achievUnlock, iconRow: t.iconRow, price: t.price, special: !!t.special, req: t.req || null, color: t.color };
}
for (const name in G.Objects) {
  const b = G.Objects[name];
  let baseCps = null;
  try { b.amount = 1; baseCps = b.cps(b); b.amount = 0; } catch (e) { baseCps = 'ERR ' + e.message; }
  out.buildings.push({
    id: b.id, name: b.name, plural: b.plural, single: b.single, bsingle: b.bsingle, bplural: b.bplural, desc: strip(b.desc),
    basePrice: b.basePrice, baseCps, iconColumn: b.iconColumn, icon: b.icon, n: b.n,
    art: b.art && { base: b.art.base, xV: b.art.xV, yV: b.art.yV, w: b.art.w, h: b.art.h, rows: b.art.rows, x: b.art.x, y: b.art.y, pic: typeof b.art.pic === 'string' ? b.art.pic : null, bg: b.art.bg },
    minigameName: b.minigameName || null, minigameUrl: b.minigameUrl || null,
    tieredUpgrades: Object.fromEntries(Object.entries(b.tieredUpgrades || {}).map(([t, u]) => [t, u.name])),
    tieredAchievs: Object.fromEntries(Object.entries(b.tieredAchievs || {}).map(([t, a]) => [t, a.name])),
    grandma: b.grandma ? b.grandma.name : null, synergies: (b.synergies || []).map(u => u.name), fortune: b.fortune ? b.fortune.name : null,
    productionAchievs: (b.productionAchievs || []).map(p => ({ pow: p.pow, name: p.achiev.name })),
    unshackleUpgrade: b.unshackleUpgrade || null,
  });
}
for (const name in G.Upgrades) {
  const u = G.Upgrades[name];
  let price = u.basePrice;
  try { if (u.priceFunc) price = u.priceFunc.call(u); } catch (e) {}
  out.upgrades.push({
    id: u.id, name: u.name, dname: strip(u.dname), desc: noquote(u.desc), quote: quote(u.desc), baseDesc: noquote(u.baseDesc),
    basePrice: num(u.basePrice), price: num(price), priceLumps: u.priceLumps || 0, icon: u.icon, pool: u.pool,
    power: typeof u.power === 'function' ? 'fn' : u.power, tier: u.tier,
    buildingTie: u.buildingTie ? u.buildingTie.name : null, buildingTie1: u.buildingTie1 ? u.buildingTie1.name : null, buildingTie2: u.buildingTie2 ? u.buildingTie2.name : null,
    order: u.order, unlockAt: u.unlockAt ? { cookies: u.unlockAt.cookies, require: u.unlockAt.require || null, season: u.unlockAt.season || null } : null,
    parents: (u.parents || []).map(p => p.name), posX: u.posX, posY: u.posY, lasting: !!u.lasting, kitten: !!u.kitten, season: u.season || null,
    showIf: !!u.showIf, isPermanentUpgradeSlot: !!u.isPermanentUpgradeSlot, techUnlock: u.techUnlock || [],
    hasDescFunc: !!u.descFunc, hasBuy: !!u.buyFunction, hasToggle: !!u.toggleInto, clickFunction: !!u.clickFunction,
  });
}
for (const name in G.Achievements) {
  const a = G.Achievements[name];
  out.achievements.push({ id: a.id, name: a.name, desc: noquote(a.desc), quote: quote(a.desc), baseDesc: noquote(a.baseDesc), icon: a.icon, pool: a.pool, order: a.order, threshold: a.threshold || null, tier: a.tier || null, buildingTie: a.buildingTie ? a.buildingTie.name : null });
}
out.unlockAt = (G.UnlockAt || []).map(u => ({ cookies: u.cookies, name: u.name, require: u.require || null, season: u.season || null }));
out.misc.grandmaSynergies = G.GrandmaSynergies;
out.misc.bankAchievements = (G.BankAchievements || []).map(a => a.name);
out.misc.cpsAchievements = (G.CpsAchievements || []).map(a => a.name);
out.misc.santaDrops = G.santaDrops; out.misc.santaLevels = G.santaLevels; out.misc.reindeerDrops = G.reindeerDrops;
out.misc.easterEggs = G.easterEggs; out.misc.eggDrops = G.eggDrops; out.misc.rareEggDrops = G.rareEggDrops; out.misc.halloweenDrops = G.halloweenDrops; out.misc.heartDrops = G.heartDrops;
out.misc.seasons = {};
for (const k in G.seasons || {}) { const s = G.seasons[k]; out.misc.seasons[k] = { name: s.name, start: strip(s.start), over: strip(s.over), trigger: s.trigger, triggerUpgrade: s.triggerUpgrade ? s.triggerUpgrade.name : null }; }
out.misc.dragonLevels = (G.dragonLevels || []).map(d => ({ name: d.name, action: strip(d.action), pic: d.pic, costStr: (function () { try { return strip(d.costStr()); } catch (e) { return null; } })() }));
out.misc.dragonAuras = {};
for (const k in G.dragonAuras || {}) { const a = G.dragonAuras[k]; out.misc.dragonAuras[k] = { name: a.name, desc: strip(a.desc), pic: a.pic }; }
out.misc.fortunes = G.fortunes || null;
out.misc.lumpAges = { mature: G.lumpMatureAge, ripe: G.lumpRipeAge, overripe: G.lumpOverripeAge };
out.misc.permanentUpgradeSlots = G.permanentUpgradeSlots || null;
out.misc.ascensionModes = {};
for (const k in G.ascensionModes || {}) { const m = G.ascensionModes[k]; out.misc.ascensionModes[k] = { name: m.name, desc: strip(m.desc), icon: m.icon }; }
out.misc.heavenlyPower = G.heavenlyPower;
out.misc.counts = { upgrades: out.upgrades.length, achievements: out.achievements.length, buildings: out.buildings.length, prestige: out.upgrades.filter(u => u.pool === 'prestige').length, cookies: out.upgrades.filter(u => u.pool === 'cookie').length };
fs.writeFileSync('cc-data.json', JSON.stringify(out, null, 1));
console.log('counts ' + JSON.stringify(out.misc.counts));
console.log('buildings: ' + out.buildings.map(b => b.name + '=' + b.basePrice + '/' + b.baseCps).join(', '));
