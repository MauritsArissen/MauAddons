const luaparse = require('luaparse');
const fs = require('fs');
let failed = 0;
for (const file of process.argv.slice(2)) {
  try {
    luaparse.parse(fs.readFileSync(file, 'utf8'), { luaVersion: '5.1' });
    console.log('OK   ' + file);
  } catch (e) {
    failed = 1;
    console.log('FAIL ' + file + ': ' + e.message);
  }
}
process.exit(failed);
