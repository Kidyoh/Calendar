# Promo assets

Everything here regenerates the banners in `assets/banners/` and the video in `assets/video/`.

| File | What it does |
| --- | --- |
| `banner.html` | Banner template: `?style=glass|pastel|night&w=…&h=…`. Uses the app screenshots + `icon.png` next to it. |
| `render_banners.js` | Exports all 3 styles × 5 sizes with Playwright/Chromium. |
| `poster.html` / `render_posters.js` | Poster series `?id=today|calendar|glass|ethiopia|holidays&w=…&h=…`. |
| `finger.js` | Drives the live web build like a finger (glide, press, ripple, type, swipe) and records it via the Chrome screencast. |
| `record_interactions.js` | The five interaction clips. Run against a web build with `?slow=3` (Flutter `timeDilation`), footage is sped back up 3×. |
| `narration.py` | Voiceover with Kokoro (Apache-2.0), female voice `af_heart`. |
| `timing.json` | Scene timings derived from the narration lengths. |
| `motion.html` | 1920×1080 motion scenes, driven frame-by-frame via `setTime(t)`. |
| `render_video_frames.js` | Renders 30 fps frames; then: `ffmpeg -framerate 30 -i frames/f%05d.jpg -i voice.wav -c:v libx264 -crf 21 -pix_fmt yuv420p -c:a aac -shortest promo.mp4` |

Sizes: README / GitHub social 1280×640 · Google Play feature graphic 1024×500 · X header 1500×500 · Instagram post 1080×1080 · Story 1080×1920.

The GitHub social preview (`.github/social-preview.png`) has to be uploaded once by hand:
repository **Settings → General → Social preview**.
