const { chromium } = require('/opt/node-tools/node_modules/playwright');
const path = require('path');
const sizes = [['readme-hero', 1280, 640], ['play-feature', 1024, 500], ['x-header', 1500, 500], ['instagram-post', 1080, 1080], ['story', 1080, 1920]];
(async () => {
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium', args: ['--no-sandbox'] });
  const pg = await b.newPage({ viewport: { width: 1920, height: 1920 } });
  for (const style of (process.argv[2] || 'glass,pastel,night').split(',')) {
    for (const [name, w, h] of sizes) {
      await pg.goto('file://' + path.resolve('banner.html') + `?style=${style}&w=${w}&h=${h}`);
      await pg.waitForSelector('body[data-ready="1"]', { timeout: 20000 }).catch(() => {});
      await pg.waitForTimeout(500);
      await pg.locator('#b').screenshot({ path: `out/${style}-${name}-${w}x${h}.png` });
    }
  }
  await b.close();
})();
