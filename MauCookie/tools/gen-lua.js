// Generates the MauCookie data files from cc-data.json (extracted from the
// original game's main.js).  Output: MauCookie/Data_*.lua
const fs = require('fs');
const path = require('path');
const d = require('./cc-data.json');
const outDir = path.resolve(__dirname, '../../../../../../../Documents/MauAddons/MauCookie');
const target = fs.existsSync(outDir) ? outDir : 'C:/Users/Gamer/Documents/MauAddons/MauCookie';

function clean(s) {
  if (s === null || s === undefined) return '';
  return String(s).replace(/&nbsp;/g, ' ').replace(/&reg;/g, '(R)').replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&bull;/g, '-').replace(/&quot;/g, '"').replace(/\s+/g, ' ').trim();
}
function q(s) { return '"' + clean(s).replace(/\\/g, '\\\\').replace(/"/g, '\\"') + '"'; }
function num(v) {
  if (v === null || v === undefined || typeof v !== 'number' || !isFinite(v)) return 'nil';
  if (Number.isInteger(v) && Math.abs(v) < 1e15) return String(v);
  return v.toExponential(12).replace(/\.?0+e/, 'e').replace('e+', 'e');
}
function icon(i) { return Array.isArray(i) ? '{' + Math.round(i[0]) + ',' + Math.round(i[1]) + '}' : 'nil'; }
function list(arr) { return '{' + (arr || []).map(q).join(',') + '}'; }
function header(what) { return '-- MauCookie: ' + what + ', generated from the original game\'s data (version ' + d.version + ').\n-- Do not edit by hand; regenerate with scratchpad ccgen/gen-lua.js.\n\nlocal _, NS = ...\n\n'; }

// Buildings
let out = header('buildings');
out += 'NS.BUILDINGS = {\n';
for (const b of d.buildings) {
  const art = b.art || {};
  out += '\t{ id = ' + b.id + ', name = ' + q(b.name) + ', plural = ' + q(b.plural) + ', single = ' + q(b.single) + ', bsingle = ' + q(b.bsingle) + ', bplural = ' + q(b.bplural) + ', desc = ' + q(b.desc) + ',\n';
  out += '\t\tbasePrice = ' + num(b.basePrice) + ', baseCps = ' + num(typeof b.baseCps === 'number' ? b.baseCps : 0) + ', iconColumn = ' + b.iconColumn + ', icon = ' + b.icon + ', n = ' + b.n + ',\n';
  out += '\t\tart = { base = ' + q(art.base || b.name.toLowerCase()) + ', bg = ' + q(art.bg || '') + ', pic = ' + (art.pic ? q(art.pic) : 'nil') + ', xV = ' + num(art.xV ?? 0) + ', yV = ' + num(art.yV ?? 0) + ', w = ' + num(art.w ?? 64) + ', rows = ' + num(art.rows ?? 1) + ', x = ' + num(art.x ?? 0) + ', y = ' + num(art.y ?? 0) + ' },\n';
  out += '\t\tminigame = ' + (b.minigameName ? q(b.minigameName) : 'nil') + ', grandma = ' + (b.grandma ? q(b.grandma) : 'nil') + ', fortune = ' + (b.fortune ? q(b.fortune) : 'nil') + ', unshackle = ' + (b.unshackleUpgrade ? q(b.unshackleUpgrade) : 'nil') + ',\n';
  out += '\t\tsynergies = ' + list(b.synergies) + ',\n';
  out += '\t\ttiered = { ' + Object.entries(b.tieredUpgrades).map(([t, n]) => '[' + (isNaN(t) ? q(t) : t) + '] = ' + q(n)).join(', ') + ' },\n';
  out += '\t\ttieredAchievs = { ' + Object.entries(b.tieredAchievs).map(([t, n]) => '[' + (isNaN(t) ? q(t) : t) + '] = ' + q(n)).join(', ') + ' },\n';
  out += '\t\tproductionAchievs = { ' + b.productionAchievs.map(p => '{ pow = ' + num(p.pow) + ', name = ' + q(p.name) + ' }').join(', ') + ' },\n';
  out += '\t},\n';
}
out += '}\n\nNS.TIERS = {\n';
for (const [k, t] of Object.entries(d.tiers)) {
  out += '\t[' + (isNaN(k) ? q(k) : k) + '] = { name = ' + q(t.name) + ', unlock = ' + t.unlock + ', achievUnlock = ' + num(t.achievUnlock) + ', iconRow = ' + t.iconRow + ', price = ' + num(t.price) + ', special = ' + (t.special ? 'true' : 'false') + ', req = ' + (t.req ? q(t.req) : 'nil') + ', color = ' + q(t.color) + ' },\n';
}
out += '}\n';
fs.writeFileSync(path.join(target, 'Data_Buildings.lua'), out);

// Upgrades
out = header('upgrades');
out += 'NS.UPGRADES = {\n';
for (const u of d.upgrades) {
  const fields = [
    'name = ' + q(u.name),
    'desc = ' + q(u.desc),
  ];
  if (u.quote) fields.push('quote = ' + q(u.quote));
  fields.push('price = ' + num(u.price !== null ? u.price : u.basePrice));
  if (u.priceLumps) fields.push('lumps = ' + num(u.priceLumps));
  fields.push('icon = ' + icon(u.icon));
  if (u.pool) fields.push('pool = ' + q(u.pool));
  if (u.tier) fields.push('tier = ' + (isNaN(u.tier) ? q(u.tier) : u.tier));
  if (u.buildingTie) fields.push('building = ' + q(u.buildingTie));
  if (u.buildingTie1) fields.push('b1 = ' + q(u.buildingTie1));
  if (u.buildingTie2) fields.push('b2 = ' + q(u.buildingTie2));
  if (u.power && u.power !== 'fn') fields.push('power = ' + num(u.power));
  if (u.power === 'fn') fields.push('powerFn = true');
  if (u.kitten) fields.push('kitten = true');
  if (u.season) fields.push('season = ' + q(u.season));
  if (u.unlockAt) fields.push('unlockCookies = ' + num(u.unlockAt.cookies) + (u.unlockAt.require ? ', unlockRequire = ' + q(u.unlockAt.require) : '') + (u.unlockAt.season ? ', unlockSeason = ' + q(u.unlockAt.season) : ''));
  if (u.parents && u.parents.length) fields.push('parents = ' + list(u.parents));
  if (typeof u.posX === 'number') fields.push('posX = ' + num(Math.round(u.posX)) + ', posY = ' + num(Math.round(u.posY)));
  if (u.lasting) fields.push('lasting = true');
  if (u.isPermanentUpgradeSlot) fields.push('slot = true');
  fields.push('order = ' + num(u.order));
  out += '\t{ ' + fields.join(', ') + ' },\n';
}
out += '}\n';
fs.writeFileSync(path.join(target, 'Data_Upgrades.lua'), out);

// Achievements
out = header('achievements');
out += 'NS.ACHIEVEMENTS = {\n';
for (const a of d.achievements) {
  const fields = ['name = ' + q(a.name), 'desc = ' + q(a.desc)];
  if (a.quote) fields.push('quote = ' + q(a.quote));
  fields.push('icon = ' + icon(a.icon));
  fields.push('pool = ' + q(a.pool || 'normal'));
  if (a.threshold) fields.push('threshold = ' + num(a.threshold));
  if (a.tier) fields.push('tier = ' + (isNaN(a.tier) ? q(a.tier) : a.tier));
  if (a.buildingTie) fields.push('building = ' + q(a.buildingTie));
  fields.push('order = ' + num(a.order));
  out += '\t{ ' + fields.join(', ') + ' },\n';
}
out += '}\n';
fs.writeFileSync(path.join(target, 'Data_Achievements.lua'), out);

// Misc
const m = d.misc;
out = header('seasons, dragon, Santa, eggs and other tables');
out += 'NS.UNLOCK_AT = {\n' + d.unlockAt.map(u => '\t{ cookies = ' + num(u.cookies) + ', name = ' + q(u.name) + (u.require ? ', require = ' + q(u.require) : '') + (u.season ? ', season = ' + q(u.season) : '') + ' },').join('\n') + '\n}\n\n';
out += 'NS.GRANDMA_SYNERGIES = ' + list(m.grandmaSynergies) + '\n';
out += 'NS.BANK_ACHIEVEMENTS = ' + list(m.bankAchievements) + '\n';
out += 'NS.CPS_ACHIEVEMENTS = ' + list(m.cpsAchievements) + '\n';
out += 'NS.SANTA_DROPS = ' + list(m.santaDrops) + '\n';
out += 'NS.SANTA_LEVELS = ' + list(m.santaLevels) + '\n';
out += 'NS.REINDEER_DROPS = ' + list(m.reindeerDrops) + '\n';
out += 'NS.EASTER_EGGS = ' + list(m.easterEggs) + '\n';
out += 'NS.EGG_DROPS = ' + list(m.eggDrops) + '\n';
out += 'NS.RARE_EGG_DROPS = ' + list(m.rareEggDrops) + '\n';
out += 'NS.HALLOWEEN_DROPS = ' + list(m.halloweenDrops) + '\n';
out += 'NS.HEART_DROPS = ' + list(m.heartDrops) + '\n\n';
out += 'NS.SEASONS = {\n' + Object.entries(m.seasons).map(([k, s]) => '\t' + k + ' = { name = ' + q(s.name) + ', start = ' + q(s.start) + ', over = ' + q(s.over) + ', trigger = ' + q(s.trigger) + ' },').join('\n') + '\n}\n\n';
out += 'NS.DRAGON_LEVELS = {\n' + m.dragonLevels.map(l => '\t{ name = ' + q(l.name) + ', action = ' + q(l.action) + ', pic = ' + l.pic + ', costStr = ' + q(l.costStr || '') + ' },').join('\n') + '\n}\n\n';
out += 'NS.DRAGON_AURAS = {\n' + Object.entries(m.dragonAuras).map(([k, a]) => '\t[' + k + '] = { name = ' + q(a.name) + ', desc = ' + q(a.desc) + ', pic = ' + icon(a.pic) + ' },').join('\n') + '\n}\n\n';
out += 'NS.ASCENSION_MODES = {\n' + Object.entries(m.ascensionModes).map(([k, a]) => '\t[' + k + '] = { name = ' + q(a.name) + ', desc = ' + q(a.desc) + ', icon = ' + icon(a.icon) + ' },').join('\n') + '\n}\n';
fs.writeFileSync(path.join(target, 'Data_Misc.lua'), out);

const sizes = ['Data_Buildings.lua', 'Data_Upgrades.lua', 'Data_Achievements.lua', 'Data_Misc.lua'].map(f => f + ' ' + fs.statSync(path.join(target, f)).size);
console.log('written to ' + target + ': ' + sizes.join(', '));
console.log('unlockAt has kittens: ' + d.unlockAt.filter(u => /Kitten/.test(u.name)).length + ', mice: ' + d.unlockAt.filter(u => /mouse/.test(u.name)).length + ', total ' + d.unlockAt.length);
console.log('pools toggle: ' + d.upgrades.filter(u => u.pool === 'toggle').map(u => u.name).join(' | '));
console.log('tech: ' + d.upgrades.filter(u => u.pool === 'tech').map(u => u.name).join(' | '));
console.log('powerFn: ' + d.upgrades.filter(u => u.power === 'fn').map(u => u.name).join(' | '));
