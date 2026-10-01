#!/usr/bin/env python3
"""Generate the demo storyteller audio + sentence-level timings.

Each sentence is synthesised separately so the in-app transcript can be
highlighted exactly in sync with the audio. Output:
  Memoire/Resources/Audio/<story-id>.m4a
  Memoire/Resources/stories.json   (stories + segment start/end times)

Backends:
  --backend say     macOS `say` placeholder voice (offline)
  --backend gemini  Gemini TTS (needs GEMINI_API_KEY in env or .env)

Demo content only: in production, Mémoire never synthesises a storyteller's
voice — every archive answer is an excerpt of a real call recording.
"""
import argparse, base64, json, os, struct, subprocess, sys, tempfile, urllib.request, wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "scripts", "stories.source.json")
AUDIO_DIR = os.path.join(ROOT, "Memoire", "Resources", "Audio")
OUT_JSON = os.path.join(ROOT, "Memoire", "Resources", "stories.json")
CACHE = os.path.join(ROOT, "scripts", ".cache")
RATE = 24000
PAUSE = 0.55  # seconds of silence between sentences


def load_env_key():
    key = os.environ.get("GEMINI_API_KEY")
    env = os.path.join(ROOT, ".env")
    if not key and os.path.exists(env):
        for line in open(env):
            if line.startswith("GEMINI_API_KEY="):
                key = line.split("=", 1)[1].strip().strip('"')
    return key


def to_pcm16_mono(src_path, dst_path):
    subprocess.run(["afconvert", "-f", "WAVE", "-d", f"LEI16@{RATE}", "-c", "1", src_path, dst_path],
                   check=True, capture_output=True)


def tts_say(text, out_wav, voice):
    with tempfile.NamedTemporaryFile(suffix=".aiff", delete=False) as t:
        tmp = t.name
    subprocess.run(["say", "-v", voice, "-r", "150", "-o", tmp, text], check=True)
    to_pcm16_mono(tmp, out_wav)
    os.unlink(tmp)


def tts_gemini(text, out_wav, voice, style, model):
    key = load_env_key()
    if not key:
        sys.exit("GEMINI_API_KEY missing")
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
    body = {
        "contents": [{"role": "user", "parts": [{"text": text, "speechMetadata": {"style": style}}]}],
        "generationConfig": {
            "responseModalities": ["AUDIO"],
            "speechConfig": {"voiceConfig": {"prebuiltVoiceConfig": {"voiceName": voice}}},
        },
    }
    req = urllib.request.Request(url, data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json", "x-goog-api-key": key})
    with urllib.request.urlopen(req, timeout=120) as r:
        data = json.load(r)
    part = data["candidates"][0]["content"]["parts"][0]["inlineData"]
    raw = base64.b64decode(part["data"])
    mime = part.get("mimeType", "")
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as t:
        tmp = t.name
    if raw[:4] == b"RIFF":
        open(tmp, "wb").write(raw)
    else:  # raw little-endian PCM, rate in mime ("audio/L16;codec=pcm;rate=24000")
        rate = 24000
        for p in mime.split(";"):
            if p.strip().startswith("rate="):
                rate = int(p.split("=")[1])
        with wave.open(tmp, "wb") as w:
            w.setnchannels(1); w.setsampwidth(2); w.setframerate(rate); w.writeframes(raw)
    to_pcm16_mono(tmp, out_wav)
    os.unlink(tmp)


def read_frames(path):
    with wave.open(path, "rb") as w:
        return w.readframes(w.getnframes()), w.getnframes() / w.getframerate()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--backend", choices=["say", "gemini"], default="say")
    ap.add_argument("--voice", default=None)
    ap.add_argument("--model", default="gemini-3.8-flash-tts")
    ap.add_argument("--only", default=None, help="comma separated story ids")
    args = ap.parse_args()

    src = json.load(open(SRC))
    os.makedirs(AUDIO_DIR, exist_ok=True)
    os.makedirs(CACHE, exist_ok=True)
    voice = args.voice or ("Grandma (English (UK))" if args.backend == "say" else "Sulafat")
    style = "warm, unhurried, remembering fondly with a smile, light French accent, natural pauses"
    only = set(args.only.split(",")) if args.only else None
    silence = b"\x00\x00" * int(RATE * PAUSE)

    out = {"storyteller": src["storyteller"], "stories": []}
    for story in src["stories"]:
        frames, segments, t = b"", [], 0.0
        regenerate = only is None or story["id"] in only
        for i, sentence in enumerate(story["sentences"]):
            wav = os.path.join(CACHE, f"{args.backend}-{story['id']}-{i}.wav")
            if regenerate or not os.path.exists(wav):
                print(f"  {story['id']}[{i}] …", flush=True)
                if args.backend == "say":
                    tts_say(sentence, wav, voice)
                else:
                    tts_gemini(sentence, wav, voice, style, args.model)
            pcm, dur = read_frames(wav)
            segments.append({"text": sentence, "start": round(t, 3), "end": round(t + dur, 3)})
            frames += pcm + silence
            t += dur + PAUSE
        full = os.path.join(CACHE, f"{story['id']}.wav")
        with wave.open(full, "wb") as w:
            w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE); w.writeframes(frames)
        m4a = os.path.join(AUDIO_DIR, f"{story['id']}.m4a")
        subprocess.run(["afconvert", "-f", "m4af", "-d", "aac", "-b", "64000", full, m4a], check=True)
        entry = {k: v for k, v in story.items() if k != "sentences"}
        entry["segments"] = segments
        entry["duration"] = round(t, 2)
        entry["audio"] = story["id"]
        entry["voice"] = args.backend
        out["stories"].append(entry)
        print(f"{story['id']}: {t:.1f}s")
    json.dump(out, open(OUT_JSON, "w"), indent=2, ensure_ascii=False)
    print("wrote", OUT_JSON)


if __name__ == "__main__":
    main()
