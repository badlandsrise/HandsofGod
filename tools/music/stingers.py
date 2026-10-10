"""Stingers: short statements of the hand motif for milestones.

  region_opened.ogg  ~5 s  the motif, then the motif again a step higher (rising)
  dream_done.ogg     ~3 s  a warm kalimba/harp answer that resolves home
  power_unlocked.ogg ~2.5 s harp sweep up, the motif's "opening" on glockenspiel
  era_complete.ogg   ~9 s  the fullest statement: motif grown to the octave,
                            strings, horn, flute, choir, timpani, then the answer

All in D, mostly D major (brighter than Era 1's dorian so they read as reward).
Run:  python3 tools/music/stingers.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from common import GM, SR, Song, dbfs, fit_oneshot, normalise, out_path, peak, render_song, write_ogg  # noqa: E402
import motif as M  # noqa: E402

KEY = 62


def play(s, ch, phrase, t, key=KEY, scale="major", shift=0, vel=80, legato=0.95, minlen=0.0):
    for pt, d in M.realise(phrase, key, scale, shift):
        if pt is not None:
            s.note(ch, pt, t, max(d * legato, minlen), vel)
        t += d
    return t


def P(deg, octave=0, scale="major"):
    return M.pitch(deg, KEY, scale) + 12 * octave


def region_opened():
    s = Song(96, 3)
    s.program(0, GM["pan_flute"], vol=100, reverb=80)
    s.program(1, GM["kalimba"], vol=90, pan=84, reverb=80)
    s.program(2, GM["slow_strings"], vol=80, reverb=90)
    s.program(3, GM["harp"], vol=80, pan=40, reverb=80)
    t = play(s, 0, M.MOTIF, 0.0, KEY + 12, vel=82)         # 6 beats
    play(s, 1, M.MOTIF, 3.0, KEY + 12, shift=2, vel=64, minlen=1.0)  # echo a third higher, overlapping
    s.chord(2, [P(0, -1), P(4, -1), P(2, 0)], 0.0, 4.0, 56)
    s.ramp(2, 11, 50, 120, 0.0, 3.0)
    s.chord(2, [P(3, -1), P(5, -1), P(0, 0)], 4.0, 3.0, 60)   # IV
    s.chord(2, [P(4, -1), P(6, -1), P(1, 0), P(4, 0)], 6.0, 3.0, 64)  # V, open (it's a door)
    for k, d in enumerate([0, 2, 4, 7, 9, 11]):
        s.note(3, P(d, -1), 6.0 + k * 0.12, 2.5, 60)
    return s, 5.2


def dream_done():
    s = Song(100, 4)
    s.program(0, GM["kalimba"], vol=100, reverb=80)
    s.program(1, GM["harp"], vol=84, pan=44, reverb=80)
    s.program(2, GM["pad_warm"], vol=70, reverb=80)
    play(s, 0, [(4, 0.5), (3, 0.5), (2, 0.5), (1, 0.5), (0, 2.0)], 0.0, KEY + 12, vel=80, minlen=1.0)
    for k, d in enumerate([0, 2, 4, 7]):
        s.note(1, P(d, -1), 2.0 + k * 0.1, 3.0, 62)
    s.chord(2, [P(0, -1), P(2, -1), P(4, -1)], 0.0, 4.0, 60)
    return s, 3.0


def power_unlocked():
    s = Song(120, 4)
    s.program(0, GM["harp"], vol=90, reverb=80)
    s.program(1, GM["glock"], vol=84, pan=80, reverb=85)
    s.program(2, GM["pad_halo"], vol=70, reverb=90)
    for k in range(10):
        s.note(0, P(k, -1), k * 0.12, 2.0, 50 + k * 3)
    play(s, 1, M.TAIL, 1.25, KEY + 12, vel=76, minlen=1.0)
    s.chord(2, [P(0, -1), P(4, -1), P(2, 0)], 0.0, 4.0, 62)
    s.ramp(2, 11, 40, 127, 0.0, 1.5)
    return s, 2.6


def era_complete():
    s = Song(84, 3)
    s.program(0, GM["flute"], vol=100, reverb=80)
    s.program(1, GM["strings"], vol=92, reverb=85)
    s.program(2, GM["horn"], vol=80, pan=50, reverb=80)
    s.program(3, GM["choir"], vol=72, reverb=95)
    s.program(4, GM["timpani"], vol=90, reverb=70)
    s.program(5, GM["harp"], vol=80, pan=36, reverb=80)
    s.program(6, GM["kalimba"], vol=74, pan=90, reverb=80)
    # Motif grown to the octave on flute, doubled by horn an octave lower.
    t = play(s, 0, M.GROWN, 0.0, KEY + 12, vel=88)              # 6 beats
    play(s, 2, M.GROWN, 0.0, KEY, vel=70)
    # Then the answer, resolving home with everything.
    ans = [(6, 0.5), (5, 0.5), (4, 1.0), (2, 1.0), (1, 1.0), (0, 4.5)]
    play(s, 0, ans, t, KEY + 12, vel=84)
    play(s, 6, M.HEAD, t + 0.5, KEY + 24, vel=56, minlen=1.0)
    # Harmony: I - vi - IV - V - I
    prog = [(0, 0.0, 2.0), (5, 2.0, 1.0), (3, 3.0, 1.5), (4, 4.5, 1.5), (3, 6.0, 1.5), (4, 7.5, 1.5), (0, 9.0, 4.5)]
    for deg, b, d in prog:
        voic = [P(deg, -2), P(deg, -1), P(deg + 2, -1), P(deg + 4, -1)]
        s.chord(1, voic, b, d, 72 if b < 9 else 80)
        s.chord(3, [P(deg + 2, -1), P(deg + 4, -1), P(deg, 0)], b, d, 60)
    s.ramp(1, 11, 60, 127, 0.0, 5.0)
    # Timpani: soft roll swelling into the final chord.
    for k in range(16):
        s.note(4, 38, 7.5 + k * 0.1, 0.12, 30 + k * 4)
    s.note(4, 38, 9.0, 2.0, 100)
    s.note(4, 45, 0.0, 1.0, 64)
    # Harp spread on the final chord.
    for k, d in enumerate([0, 4, 7, 9, 11, 14]):
        s.note(5, P(d, -1), 9.0 + k * 0.1, 4.0, 64)
    return s, 9.5


STINGERS = {
    "region_opened": region_opened,
    "dream_done": dream_done,
    "power_unlocked": power_unlocked,
    "era_complete": era_complete,
}


def main():
    outdir = out_path("assets", "audio", "music", "stingers")
    for name, fn in STINGERS.items():
        song, secs = fn()
        raw = render_song(song, tail_beats=6)
        a = fit_oneshot(raw, int(secs * SR), fade_s=min(1.2, secs * 0.35))
        a = normalise(a, -1.0)
        write_ogg(os.path.join(outdir, name + ".ogg"), a)
        print(f"  {name}: {secs:.2f}s peak {dbfs(peak(a)):.1f} dBFS")


if __name__ == "__main__":
    main()
