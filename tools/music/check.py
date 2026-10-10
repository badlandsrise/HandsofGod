"""Check the rendered audio and write the era preview mixes.

  - ffprobe duration of every music file and loop
  - decoded sample counts of each era's stems must match exactly
  - loop seams: RMS of the first and last 50 ms, and the sample step across
    the seam compared with typical steps inside the file
  - combined stem peak (all five stems at once must stay below 0 dBFS)
  - loudness (EBU R128) of each era's mixes, which must sit within 1.5 LU of
    Era 1's, so the music doesn't jump in level when the era changes
  - tools/music/preview_era<N>.mp3: 60 s of the stems layered as the game would
    (Era 2's opens with its arrival stinger, as it does on the era change)
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
from common import SR, dbfs, lufs, out_path, peak, read_audio, write_mp3  # noqa: E402

MUSIC = out_path("assets", "audio", "music")
SFX = out_path("assets", "audio", "sfx")
ERAS = ["era1", "era2"]
STEMS = ["base", "rhythm", "melody", "colour", "tense"]
MIXES = {  # what the director plays together (colour is at 0.6 by the fire)
    "night": {"base": 1},
    "day": {"base": 1, "rhythm": 1},
    "holding": {"base": 1, "rhythm": 1, "melody": 1, "colour": 1},
    "fire": {"base": 1, "colour": 0.6},
    "threat": {"base": 1, "tense": 1},
}


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

    loud = {}
    for era in ERAS:
        if not os.path.exists(os.path.join(MUSIC, era, "base.ogg")):
            print(f"{era}: not rendered")
            continue
        print(f"{era} stems (decoded):")
        stems = {}
        for s in STEMS:
            stems[s] = read_audio(os.path.join(MUSIC, era, s + ".ogg"))
            print(f"  {s:7s} {len(stems[s])} samples, peak {dbfs(peak(stems[s])):6.1f} dBFS")
        lens = {len(a) for a in stems.values()}
        if len(lens) != 1:
            print("  BAD: stem lengths differ", lens)
            good = False
        full = stems["base"] + stems["rhythm"] + stems["melody"] + stems["colour"]
        every = full + stems["tense"]
        print(f"  base+rhythm+melody+colour peak {dbfs(peak(full)):.2f} dBFS; "
              f"with tense too {dbfs(peak(every)):.2f} dBFS")
        if peak(every) >= 1.0:
            print("  BAD: all stems together clip")
            good = False
        loud[era] = {m: lufs(sum(stems[s] * g for s, g in mix.items())) for m, mix in MIXES.items()}
        print("  loudness: " + ", ".join(f"{m} {v:.1f}" for m, v in loud[era].items()) + " LUFS")
        print(f"{era} loop seams:")
        for s, a in stems.items():
            good &= seam(a, f"{era}/" + s)
        good &= seam(full, f"{era}/all four")
        preview(stems, era)
    if "era1" in loud:
        for era, lv in loud.items():
            diff = max(abs(v - loud["era1"][m]) for m, v in lv.items())
            ok = diff <= 1.5
            good &= ok
            print(f"  {'OK ' if ok else 'BAD'} {era} loudness within {diff:.1f} LU of era1 in every mix")

    print("Other loop seams:")
    good &= seam(read_audio(os.path.join(MUSIC, "title.ogg")), "title")
    for f in sorted(glob.glob(os.path.join(SFX, "*_loop.ogg"))):
        good &= seam(read_audio(f), os.path.basename(f))
    print("ALL GOOD" if good else "PROBLEMS FOUND")
    return 0 if good else 1


def preview(stems, era):
    """60 s of an era's stems as the game layers them; see the module docstring.

    Layer targets change over time with 1.5 s linear fades like autoload/audio.gd.
    An era with an arrival stinger (stingers/<era>_begin.ogg) opens with it, as
    on era_changed: the stinger 2 dB up and the stems ducked to 0.45 under it.
    """
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
    sting = os.path.join(MUSIC, "stingers", era + "_begin.ogg")
    if os.path.exists(sting):
        st = read_audio(sting)[:n]
        duck = np.ones(n)
        k = int(min(len(st) / SR, 4.0) * SR)
        duck[:k] = 0.45
        duck[k:k + int(1.5 * SR)] = np.linspace(0.45, 1.0, int(1.5 * SR))
        mix *= duck[:, None]
        mix[:len(st)] += st * 10 ** (2 / 20)
    mix[-SR * 2:] *= np.linspace(1, 0, SR * 2)[:, None]
    if peak(mix) > 10 ** (-1 / 20):  # the stinger on top: in game the music bus sits at -6 dB
        mix *= 10 ** (-1 / 20) / peak(mix)
    mix = np.clip(mix, -1, 1)
    write_mp3(out_path("tools", "music", f"preview_{era}.mp3"), mix)
    print(f"  preview written: tools/music/preview_{era}.mp3 (peak {dbfs(peak(mix)):.2f} dBFS)")


if __name__ == "__main__":
    sys.exit(main())
