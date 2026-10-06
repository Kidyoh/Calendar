const { chromium } = require('/opt/node-tools/node_modules/playwright');
const path = require('path'); const fs = require('fs');
(async () => {
  const total = JSON.parse(fs.readFileSync('timing.json')).total, fps = 30, n = Math.ceil(total * fps);
  fs.mkdirSync('frames2', { recursive: true });
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium', args: ['--no-sandbox'] });
  const pg = await b.newPage({ viewport: { width: 1920, height: 1080 } });
  await pg.goto('file://' + path.resolve('motion.html')); await pg.evaluate(() => window.ready); await pg.waitForTimeout(1000);
  for (let i = 0; i < n; i++) {
    await pg.evaluate(async t => { await setTime(t); }, i / fps);
    await pg.screenshot({ path: `frames2/f${String(i).padStart(5, '0')}.jpg`, type: 'jpeg', quality: 93 });
  }
  console.log('frames', n);
  await b.close();
})();
