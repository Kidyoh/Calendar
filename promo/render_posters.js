const { chromium } = require('/opt/node-tools/node_modules/playwright');
const path = require('path');
const ids = (process.argv[2] || 'today,calendar,glass,ethiopia,holidays').split(',');
const sizes = [['square', 1080, 1080], ['portrait', 1080, 1350], ['wide', 1920, 1080]];
(async () => {
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium', args: ['--no-sandbox'] });
  const pg = await b.newPage({ viewport: { width: 1920, height: 1350 }, deviceScaleFactor: 2 });
  for (const [i, id] of ids.entries()) for (const [name, w, h] of sizes) {
    await pg.goto('file://' + path.resolve('poster.html') + `?id=${id}&w=${w}&h=${h}`);
    await pg.waitForSelector('body[data-ready="1"]', { timeout: 20000 }).catch(() => {});
    await pg.locator('#p').screenshot({ path: `out/0${['today','calendar','glass','ethiopia','holidays'].indexOf(id) + 1}-${id}-${name}.png` });
  }
  await b.close();
})();
