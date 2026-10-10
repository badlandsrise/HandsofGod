"""Check the rendered audio and write the Era 1 preview mix.

  - ffprobe duration of every music file and loop
  - decoded sample counts of the Era 1 stems must match exactly
  - loop seams: RMS of the first and last 50 ms, and the sample step across
    the seam compared with typical steps inside the file
  - combined stem peak
  - tools/music/preview_era1.mp3: 60 s of the stems layered as the game would
    (night: base; day: + rhythm; hand holding: + melody, colour; a threat
    warning swaps rhythm for tense and drops melody; then back to calm)

Run:  python3 tools/music/check.py
"""
import glob
import os
import subprocess
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from common import SR, dbfs, out_path, peak, read_audio, write_mp3  # noqa: E402

MUSIC = out_path("assets", "audio", "music")
SFX = out_path("assets", "audio", "sfx")


def ffprobe_dur(path):
    r = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration",
                        "-of", "default=nw=1:nk=1", path], capture_output=True, text=True, check=True)
    return float(r.stdout.strip())


def rms(x):
    return dbfs(np.sqrt(np.mean(x ** 2)))


def seam(a, name):
    k = int(0.05 * SR)
    head, tail = rms(a[:k]), rms(a[-k:])
    step = np.max(np.abs(a[0] - a[-1]))
    typical = np.percentile(np.max(np.abs(np.diff(a, axis=0)), axis=1), 99.9)
    # A downbeat at the head is musical; a tail much louder than the head would mean
    # a sound cut off at the seam. The sample step across the seam catches clicks.
    ok = (tail - head) < 6.0 and step <= typical
    print(f"  {'OK ' if ok else 'BAD'} {name:28s} head {head:6.1f} dB  tail {tail:6.1f} dB  "
          f"seam step {step:.4f} (99.9% step {typical:.4f})")
    return ok


def main():
    good = True
    print("Durations (ffprobe):")
    for f in sorted(glob.glob(os.path.join(MUSIC, "**", "*.ogg"), recursive=True)) + \
            sorted(glob.glob(os.path.join(SFX, "*_loop.ogg"))):
        print(f"  {os.path.relpath(f, out_path()):45s} {ffprobe_dur(f):8.3f} s")

    print("Era 1 stems (decoded):")
    stems = {}
    for s in ["base", "rhythm", "melody", "colour", "tense"]:
        stems[s] = read_audio(os.path.join(MUSIC, "era1", s + ".ogg"))
        print(f"  {s:7s} {len(stems[s])} samples, peak {dbfs(peak(stems[s])):6.1f} dBFS")
    lens = {len(a) for a in stems.values()}
    if len(lens) != 1:
        print("  BAD: stem lengths differ", lens)
        good = False
    full = stems["base"] + stems["rhythm"] + stems["melody"] + stems["colour"]
    print(f"  base+rhythm+melody+colour peak {dbfs(peak(full)):.2f} dBFS; "
          f"with tense too {dbfs(peak(full + stems['tense'])):.2f} dBFS")

    print("Loop seams:")
    for s, a in stems.items():
        good &= seam(a, "era1/" + s)
    good &= seam(full, "era1/all four")
    good &= seam(read_audio(os.path.join(MUSIC, "title.ogg")), "title")
    for f in sorted(glob.glob(os.path.join(SFX, "*_loop.ogg"))):
        good &= seam(read_audio(f), os.path.basename(f))

    # Preview: 60 s, layer targets over time, 1.5 s linear fades like autoload/audio.gd.
    n = 60 * SR
    t = np.arange(n) / SR
    plan = {  # stem: [(time_s, target)]
        "base": [(0, 1)],
        "rhythm": [(0, 0), (8, 1), (44, 0), (52, 1)],
        "melody": [(0, 0), (16, 1), (44, 0), (52, 1)],
        "colour": [(0, 0), (16, 1)],
        "tense": [(0, 0), (44, 1), (52, 0)],
    }
    mix = np.zeros((n, 2))
    for s, pts in plan.items():
        g = np.zeros(n)
        cur = 0.0
        for i, (ts, target) in enumerate(pts):
            i0 = int(ts * SR)
            i1 = int(pts[i + 1][0] * SR) if i + 1 < len(pts) else n
            ramp = np.clip(cur + (target - cur) * (t[i0:i1] - ts) / 1.5, min(cur, target), max(cur, target))
            g[i0:i1] = ramp
            cur = target
        mix += stems[s][:n] * g[:, None]
    mix[-SR * 2:] *= np.linspace(1, 0, SR * 2)[:, None]
    mix = np.clip(mix, -1, 1)
    write_mp3(out_path("tools", "music", "preview_era1.mp3"), mix)
    print(f"Preview written: tools/music/preview_era1.mp3 (peak {dbfs(peak(mix)):.2f} dBFS)")
    print("ALL GOOD" if good else "PROBLEMS FOUND")
    return 0 if good else 1


if __name__ == "__main__":
    sys.exit(main())
