"""Generate the promo voiceover with Kokoro (Apache-2.0), female voice af_heart.

pip install kokoro-onnx soundfile
curl -LO https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/kokoro-v1.0.onnx
curl -LO https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/voices-v1.0.bin
"""
import json

import numpy as np
import soundfile as sf
from kokoro_onnx import Kokoro

# Phonetic respellings help the English voice with Ethiopian words
# (Pagume -> "Pagoomay", Abiy Tsom -> "Ah-bee Tsom"); subtitles keep the real spelling.
LINES = [
    ("intro", "Meet Glass Calendar."),
    ("today", "Your days, beautifully. Tasks and meetings live on calm pastel cards, with two world clocks always at a glance."),
    ("calendar", "Flip through your months, and see every day laid out by the hour."),
    ("widgets", "Frosted glass widgets float right on your home screen."),
    ("ethiopia", "It speaks Amharic, and follows the Ethiopian calendar, Pagoomay included."),
    ("holidays", "Fasika, Meskel, Timket, and every fast, from Ah-bee Tsom to the Wednesday and Friday fasts, are built in."),
    ("sync", "And it stays in sync with Google, eye-Cloud, and Outlook."),
    ("outro", "Glass Calendar. Your time, beautifully kept."),
]

if __name__ == "__main__":
    k = Kokoro("kokoro-v1.0.onnx", "voices-v1.0.bin")
    meta = []
    for key, text in LINES:
        s, sr = k.create(text, voice="af_heart", speed=0.98, lang="en-us")
        s = np.asarray(s, dtype=np.float32)
        idx = np.where(np.abs(s) > 0.01)[0]
        s = s[max(0, idx[0] - 240): idx[-1] + 2400]
        sf.write(f"{key}.wav", s, sr)
        meta.append({"key": key, "text": text, "dur": round(len(s) / sr, 3)})
    json.dump(meta, open("meta.json", "w"), indent=1)
