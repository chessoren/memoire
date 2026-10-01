#!/usr/bin/env python3
"""One Gemini TTS request per story (free-tier friendly), then sentence timings
recovered by detecting the pauses we ask the voice to leave between sentences.
Usage: python3 scripts/generate_story_audio.py [--model gemini-3.8-flash-lite-tts] [--voice Gacrux] [--only id,id]
"""
import argparse, array, json, os, subprocess, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import generate_audio as g

def silences(pcm, rate, win=0.02):
    a = array.array("h"); a.frombytes(pcm)
    n = int(rate * win)
    rms = []
    for i in range(0, len(a) - n, n):
        chunk = a[i:i + n]
        rms.append((sum(x * x for x in chunk) / n) ** 0.5)
    peak = max(rms) or 1
    quiet = [r < peak * 0.04 for r in rms]
    runs, start = [], None
    for i, q in enumerate(quiet + [False]):
        if q and start is None: start = i
        if not q and start is not None:
            runs.append((start * win, i * win)); start = None
    total = len(a) / rate
    return runs, total

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", default="gemini-3.8-flash-lite-tts")
    ap.add_argument("--voice", default="Gacrux")
    ap.add_argument("--only", default=None)
    args = ap.parse_args()
    src = json.load(open(g.SRC))
    out = json.load(open(g.OUT_JSON)) if os.path.exists(g.OUT_JSON) else {"storyteller": src["storyteller"], "stories": []}
    by_id = {s["id"]: s for s in out["stories"]}
    style = "warm, unhurried, remembering fondly with a smile, light French accent, a clear pause between sentences"
    only = set(args.only.split(",")) if args.only else None
    for story in src["stories"]:
        if only and story["id"] not in only: continue
        wav = os.path.join(g.CACHE, f"story-{story['id']}.wav")
        if not os.path.exists(wav):
            text = " <long pause> ".join(story["sentences"])
            g.tts_gemini(text, wav, args.voice, style, args.model)
        pcm, _ = g.read_frames(wav)
        runs, total = silences(pcm, g.RATE)
        # leading/trailing silence
        inner = [r for r in runs if r[0] > 0.05 and r[1] < total - 0.05]
        k = len(story["sentences"]) - 1
        lead = runs[0][1] if runs and runs[0][0] <= 0.05 else 0.0
        tail = runs[-1][0] if runs and runs[-1][1] >= total - 0.05 else total
        # Expected boundary times from sentence lengths, snapped to the nearest real pause.
        lens = [len(x) for x in story["sentences"]]
        cand = [r for r in inner if r[1] - r[0] >= 0.25]
        cuts, after = [], lead
        for i in range(k):
            expect = lead + (tail - lead) * sum(lens[:i + 1]) / sum(lens)
            pool = [r for r in cand if r[0] > after + 0.5] or [r for r in inner if r[0] > after]
            best = min(pool, key=lambda r: abs((r[0] + r[1]) / 2 - expect) - 0.6 * (r[1] - r[0]))
            cuts.append(best); after = best[1]
        bounds = [lead] + [x for c in cuts for x in c] + [tail]
        segs = []
        for i, sentence in enumerate(story["sentences"]):
            s, e = (bounds[2 * i], bounds[2 * i + 1]) if 2 * i + 1 < len(bounds) else (bounds[-2], bounds[-1])
            segs.append({"text": sentence, "start": round(max(0, s - 0.05), 3), "end": round(e + 0.05, 3)})
        m4a = os.path.join(g.AUDIO_DIR, f"{story['id']}.m4a")
        subprocess.run(["afconvert", "-f", "m4af", "-d", "aac", "-b", "64000", wav, m4a], check=True)
        entry = {k2: v for k2, v in story.items() if k2 != "sentences"}
        entry.update(segments=segs, duration=round(total, 2), audio=story["id"], voice="gemini")
        by_id[story["id"]] = entry
        print(f"{story['id']}: {total:.1f}s, {len(cuts)} cuts for {k}")
    out["stories"] = [by_id[s["id"]] for s in src["stories"] if s["id"] in by_id]
    json.dump(out, open(g.OUT_JSON, "w"), indent=2, ensure_ascii=False)

if __name__ == "__main__":
    main()
