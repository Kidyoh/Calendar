// Drive the live Flutter web app like a finger: glide, press, ripple, type, swipe.
// D = time-dilation factor (the app runs D× slower; footage is sped up D× later).
const fs = require('fs');
const FINGER_CSS = `
#finger{position:fixed;left:0;top:0;width:44px;height:44px;margin:-22px 0 0 -22px;border-radius:50%;z-index:2147483647;pointer-events:none;
  background:radial-gradient(circle at 40% 35%,rgba(255,255,255,.95),rgba(235,235,235,.85));box-shadow:0 0 0 2px rgba(20,20,20,.18),0 8px 18px rgba(0,0,0,.28);
  opacity:0;transition-property:transform,opacity;transition-timing-function:cubic-bezier(.3,.7,.2,1)}
#finger.down{box-shadow:0 0 0 2px rgba(20,20,20,.25),0 3px 8px rgba(0,0,0,.3)}
.ripple{position:fixed;width:44px;height:44px;margin:-22px 0 0 -22px;border-radius:50%;z-index:2147483646;pointer-events:none;
  border:3px solid rgba(255,255,255,.95);box-shadow:0 0 0 2px rgba(20,20,20,.15);animation:rip var(--d) cubic-bezier(.2,.7,.3,1) forwards}
@keyframes rip{from{transform:scale(.6);opacity:.95}to{transform:scale(2.6);opacity:0}}`;

module.exports = (page, D = 1) => {
  let fx = 195, fy = 700;
  const wait = ms => page.waitForTimeout(ms * D);
  const setup = async () => {
    await page.addStyleTag({ content: FINGER_CSS });
    await page.evaluate(() => { const f = document.createElement('div'); f.id = 'finger'; document.body.appendChild(f); });
  };
  const fingerTo = async (x, y, ms, extra = '') => {
    await page.evaluate(([x, y, ms, extra]) => {
      const f = document.getElementById('finger');
      f.style.transitionDuration = ms + 'ms';
      f.style.opacity = 1;
      f.style.transform = `translate(${x}px,${y}px) ${extra}`;
    }, [x, y, ms * D, extra]);
  };
  const show = async () => { await fingerTo(fx, fy, 1); await wait(30); };
  const hide = async () => { await page.evaluate(ms => { const f = document.getElementById('finger'); f.style.transitionDuration = ms + 'ms'; f.style.opacity = 0; }, 300 * D); await wait(300); };
  const glide = async (x, y, ms = 520) => { await fingerTo(x, y, ms); await wait(ms + 40); fx = x; fy = y; };
  const tap = async (x, y, { move = 520, hold = 110, after = 450 } = {}) => {
    await glide(x, y, move);
    await fingerTo(x, y, 90, 'scale(.82)');
    await page.mouse.move(x, y); await page.mouse.down();
    await page.evaluate(([x, y, d]) => {
      const r = document.createElement('div'); r.className = 'ripple'; r.style.left = x + 'px'; r.style.top = y + 'px';
      r.style.setProperty('--d', d + 'ms'); document.body.appendChild(r); setTimeout(() => r.remove(), d + 50);
    }, [x, y, 650 * D]);
    await wait(hold);
    await page.mouse.up();
    await fingerTo(x, y, 160);
    await wait(after);
  };
  const swipe = async (x1, y1, x2, y2, ms = 420, after = 500) => {
    await glide(x1, y1, 420);
    await fingerTo(x1, y1, 80, 'scale(.82)');
    await page.mouse.move(x1, y1); await page.mouse.down();
    const steps = Math.max(8, Math.round(ms * D / 16));
    for (let i = 1; i <= steps; i++) {
      const t = i / steps, e = 1 - Math.pow(1 - t, 2);
      const x = x1 + (x2 - x1) * e, y = y1 + (y2 - y1) * e;
      await page.mouse.move(x, y);
      await page.evaluate(([x, y]) => { const f = document.getElementById('finger'); f.style.transitionDuration = '0ms'; f.style.transform = `translate(${x}px,${y}px) scale(.82)`; }, [x, y]);
      await page.waitForTimeout(ms * D / steps);
    }
    await page.mouse.up(); fx = x2; fy = y2;
    await fingerTo(x2, y2, 160);
    await wait(after);
  };
  const type = async (text, perChar = 70) => { for (const ch of text) { await page.keyboard.type(ch); await page.waitForTimeout(perChar * D); } };

  // CDP screencast recorder: every rendered frame with its timestamp.
  let cdp, frames = [], dir;
  const record = async (outDir) => {
    dir = outDir; fs.mkdirSync(dir, { recursive: true }); frames = [];
    cdp = await page.context().newCDPSession(page);
    cdp.on('Page.screencastFrame', async ({ data, metadata, sessionId }) => {
      const i = frames.length; const name = `${dir}/r${String(i).padStart(5, '0')}.jpg`;
      fs.writeFileSync(name, Buffer.from(data, 'base64')); frames.push({ t: metadata.timestamp, f: name });
      try { await cdp.send('Page.screencastFrameAck', { sessionId }); } catch {}
    });
    await cdp.send('Page.startScreencast', { format: 'jpeg', quality: 92, everyNthFrame: 1 });
  };
  const stop = async () => {
    await cdp.send('Page.stopScreencast');
    fs.writeFileSync(`${dir}/frames.json`, JSON.stringify({ D, frames }));
    return frames.length;
  };
  return { setup, show, hide, glide, tap, swipe, type, wait, record, stop };
};
