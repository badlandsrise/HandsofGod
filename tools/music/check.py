"""Check the rendered audio and write the era preview mixes.

  - ffprobe duration of every music file and loop
  - decoded sample counts of each era's stems must match exactly
  - loop seams: RMS of the first and last 50 ms, and the sample step across
    the seam compared with typical steps inside the file
  - combined stem peak (all five stems at once must stay below 0 dBFS)
  - loudness (EBU R128) of each era's mixes, which must sit within 1.5 LU of
    Era 1's, so the music doesn't jump in level when the era changes
  - tools/music/preview_era<N>.mp3: 60 s of the stems layered as the game would
    (Eras 2 to 4 open with their arrival stingers, as on the era change)
    (night: base; day: + rhythm; hand holding: + melody, colour; a threat
    warning swaps rhythm for tense and drops melody; then back to calm)
  - the ending cues (music/ending/, tools/music/ending.py): loudness against each
    cue's target (within 1 LU), peaks, loop seams for the looping cues, a silent
    tail for the one-shots, the credits 3 to 4 minutes long
  - tools/music/preview_ending.mp3: the whole goodbye as the game plays it with
    Audio.play_cue (cross-fades, the countdown paused once by letting go)

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
ERAS = ["era1", "era2", "era3", "era4"]
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
    good &= check_ending()
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


def check_ending():
    """The ending cues; see the module docstring. Returns True if all is well."""
    import ending
    d = os.path.join(MUSIC, "ending")
    if not os.path.exists(os.path.join(d, "credits.ogg")):
        print("ending: not rendered")
        return True
    good = True
    print("Ending cues:")
    cues = {}
    for name, (_, loop, target) in ending.CUES.items():
        a = read_audio(os.path.join(d, name + ".ogg"))
        cues[name] = a
        lv, pk = lufs(a), dbfs(peak(a))
        tail = rms(a[-int(0.05 * SR):])
        ok = abs(lv - target) <= 1.0 and pk < -0.9 and (loop or tail < -50)
        if name == "credits":
            ok &= 180 <= len(a) / SR <= 240
        good &= ok
        print(f"  {'OK ' if ok else 'BAD'} {name:13s} {'loop' if loop else 'one-shot':8s} {len(a) / SR:7.2f} s  "
              f"{lv:6.1f} LUFS (target {target})  peak {pk:6.2f} dBFS" + ("" if loop else f"  tail {tail:6.1f} dB"))
        if loop:
            good &= seam(a, "ending/" + name)
    preview_ending(cues)
    return good


def preview_ending(cues):
    """The goodbye as the game plays it: Audio.play_cue cross-fades (2 s) from one
    cue to the next; loops run until the next cue; when a one-shot ends, the next
    cue (play_cue's `then`) starts at once. The countdown is paused once
    (Audio.cue_level(0.35) for 6 s)."""
    fade = int(2.0 * SR)
    plan = [("last_evening", 45.0), ("countdown", 32.0), ("liftoff", None), ("wave", 30.0),
            ("goodbye", None), ("credits", None)]
    total = sum(int((secs or len(cues[n]) / SR) * SR) for n, secs in plan) + fade
    mix = np.zeros((total, 2))
    t = 0
    for i, (name, secs) in enumerate(plan):
        src = cues[name]
        n = int(secs * SR) if secs else len(src)
        if secs:   # a loop: tile it for as long as the player takes
            src = np.concatenate([src] * (n // len(src) + 2))
        seg = src[:n + fade].copy()
        env = np.ones(len(seg))
        if i:   # fade in over the outgoing loop (quickly after a one-shot has ended)
            k = fade if plan[i - 1][1] else int(0.3 * SR)
            env[:k] = np.linspace(0, 1, k)
        if secs and i + 1 < len(plan):   # a loop fades out under the next cue
            env[n:] = np.linspace(1, 0, len(seg) - n)
        if name == "countdown":   # let go at 12 s, hold again at 18 s
            k0, k1, r = int(12 * SR), int(18 * SR), int(1.0 * SR)
            env[k0:k0 + r] *= np.linspace(1, 0.35, r)
            env[k0 + r:k1] *= 0.35
            env[k1:k1 + r] *= np.linspace(0.35, 1, r)
        seg *= env[:, None]
        mix[t:t + len(seg)] += seg[:total - t]
        t += n
    mix = mix[:t]
    if peak(mix) > 10 ** (-1 / 20):
        mix *= 10 ** (-1 / 20) / peak(mix)
    write_mp3(out_path("tools", "music", "preview_ending.mp3"), mix, q=6)
    print(f"  preview written: tools/music/preview_ending.mp3 ({len(mix) / SR / 60:.1f} min, "
          f"peak {dbfs(peak(mix)):.2f} dBFS)")


if __name__ == "__main__":
    sys.exit(main())
