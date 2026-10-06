const { chromium } = require('/opt/node-tools/node_modules/playwright');
const mk = require('./finger.js');
const D = 3;
const which = (process.argv[2] || 'today,calendar,widgets,ethiopia,holidays').split(',');
(async () => {
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium', args: ['--no-sandbox'] });
  for (const clip of which) {
    const ctx = await b.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2 });
    const pg = await ctx.newPage();
    const am = clip === 'holidays';
    await pg.goto('http://localhost:8771/');
    await pg.evaluate(([l, e]) => { localStorage.clear(); localStorage.setItem('flutter.onboarded', 'true'); localStorage.setItem('flutter.language', JSON.stringify(l)); localStorage.setItem('flutter.ethiopian', String(e)); }, [am ? 'am' : 'en', am]);
    await pg.goto(`http://localhost:8771/?day=2026-10-06&slow=${D}`); await pg.waitForTimeout(7000);
    if (clip === 'calendar') { await pg.mouse.click(52, 36); }
    if (clip === 'widgets') { await pg.mouse.click(52, 36); }
    await pg.waitForTimeout(1500);
    const f = mk(pg, D); await f.setup();
    await f.glide(300, 760, 1);
    await f.record(`raw/${clip}`);
    await f.show(); await f.wait(350);
    if (clip === 'today') {
      await f.tap(143, 316, { after: 650 });           // Wednesday -> date rolls
      await f.tap(92, 316, { after: 450 });            // back to Tuesday
      await f.tap(349, 36, { after: 550 });            // + -> New event sheet
      await f.type('Coffee with Abebe', 55); await f.wait(250);
      await f.tap(155, 740, { move: 480, after: 300 }); // teal colour
      await f.tap(195, 798, { move: 420, after: 1300 }); // Add event -> card appears
    } else if (clip === 'calendar') {
      await f.tap(130, 36, { after: 700 });            // Calendar tab
      await f.tap(242, 108, { after: 650 });           // next month
      await f.tap(148, 108, { move: 420, after: 650 }); // back to October
      await f.tap(145, 316, { after: 800 });           // pick the 14th
    } else if (clip === 'widgets') {
      await f.tap(230, 36, { after: 800 });            // Widgets tab
      await f.tap(223, 229, { after: 800 });           // Monthly
      await f.tap(109, 229, { after: 700 });           // Weekly
    } else if (clip === 'ethiopia') {
      await f.tap(296, 36, { after: 700 });            // Settings
      await f.tap(157, 444, { after: 800 });           // አማርኛ
      await f.tap(204, 353, { after: 800 });           // Ethiopian
      await f.tap(195, 110, { after: 1200 });          // close sheet
    } else if (clip === 'holidays') {
      await f.tap(130, 36, { after: 650 });            // ቀን መቁጠሪያ tab
      await f.swipe(195, 700, 195, 300, 900, 500);     // scroll to holidays & fasts
      await f.tap(160, 664, { after: 600 });           // መስቀል row
      await f.tap(52, 36, { after: 1500 });            // ዛሬ -> Meskel card
    }
    await f.hide(); await f.wait(200);
    const n = await f.stop();
    await pg.screenshot({ path: `end_${clip}.png` });
    console.log(clip, 'frames', n);
    await ctx.close();
  }
  await b.close();
})();
