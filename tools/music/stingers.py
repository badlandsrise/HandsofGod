"""Stingers: short statements of the hand motif for milestones.

  region_opened.ogg  ~5 s  the motif, then the motif again a step higher (rising)
  dream_done.ogg     ~3 s  a warm kalimba/harp answer that resolves home
  power_unlocked.ogg ~2.5 s harp sweep up, the motif's "opening" on glockenspiel
  era_complete.ogg   ~9 s  the fullest statement: motif grown to the octave,
                            strings, horn, flute, choir, timpani, then the answer
  era2_begin.ogg     ~12 s the arrival in Era 2 (played on era_changed to 2): the
                            motif grown on fiddle and recorder in G, the village
                            band (lute, frame drum, strings, harp) entering

All in D, mostly D major (brighter than Era 1's dorian so they read as reward),
except the era arrivals, which are in the new era's key and tempo: era2_begin
is in G at Era 2's 90 bpm 4/4 and follows the harmony of Era 2's first four
bars (G G C G), so it lands in step with the stems starting under it.
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


def era2_begin():
    s = Song(90, 4)
    G = 67
    s.program(0, GM["fiddle"], vol=100, pan=58, reverb=70)
    s.program(1, GM["recorder"], vol=84, pan=76, reverb=75)
    s.program(2, GM["strings"], vol=88, reverb=85)
    s.program(3, GM["nylon"], vol=90, pan=44, reverb=60)
    s.program(4, GM["harp"], vol=82, pan=30, reverb=80)
    s.program(5, GM["cello"], vol=84, pan=70, reverb=65)
    s.program(6, GM["timpani"], vol=86, reverb=70)
    s.program(7, GM["celesta"], vol=70, pan=90, reverb=85)
    s.program(9, 0, vol=90, reverb=50)

    def gp(deg, octave=0):
        return M.pitch(deg, G, "major") + 12 * octave

    # The motif grown to the octave (D G A B D G), then a new answer home:
    # F# E D | C . E D | B A G -- over G G C G, Era 2's opening bars.
    tune = [(-3, 1), (0, 1), (1, .5), (2, .5), (4, 1), (7, 2),
            (6, .5), (5, .5), (4, 1), (3, 2), (5, 1), (4, 1), (2, 1), (1, 1), (0, 3)]
    second = [(2, 1), (2, 1), (3, .5), (4, .5), (7, 1), (9, 2),     # recorder: a folk second part
              (8, .5), (7, .5), (9, 1), (5, 2), (7, 1), (7, 1), (4, 1), (3, 1), (2, 3)]
    t = 0.0
    for (d, b), (d2, _) in zip(tune, second):
        s.note(0, gp(d), t, b * 0.92, 86 if b >= 1 else 76)
        s.note(1, gp(d2), t, b * 0.92, 66)
        t += b
    s.ramp(0, 11, 100, 127, 4.0, 6.0)
    s.ramp(0, 1, 0, 30, 4.4, 6.0, 4)
    # Harmony: G (2 bars) C G, strings swelling, cello roots.
    for name, b0, d, root in (("G", 0, 8, 43), ("C", 8, 4, 48), ("G", 12, 6, 43)):
        off = {"G": [0, 4, 7], "C": [5, 9, 12]}[name]
        s.chord(2, [G - 12 + o for o in off] + [G + off[0]], b0, d, 74 if b0 == 0 else 70)
        s.note(5, root, b0, d, 80)
        # The lute: fingerpicked eighths.
        arp = [root - 12 + 12, root + 7, root + 12, root + 16, root + 19, root + 16, root + 12, root + 7]
        for k in range(int(d * 2)):
            s.note(3, arp[k % 8], b0 + k * 0.5 + (0.06 if k % 2 else 0), 0.8, 60 if k % 4 == 0 else 46)
    s.ramp(2, 11, 70, 127, 0.0, 4.0)
    # Arrival: timpani and frame drum on the downbeat, harp spread up the chord.
    s.note(6, 43, 0.0, 2.0, 100)
    s.note(6, 43, 12.0, 2.0, 84)
    for k, d in enumerate([0, 2, 4, 7, 9, 11, 14]):
        s.note(4, gp(d, -1), k * 0.08, 3.0, 66)
        s.note(4, gp(d, -1), 12.0 + k * 0.1, 4.0, 60)
    for bar in range(4):
        b = bar * 4
        s.note(9, 41, b, 0.3, 72 if bar == 0 else 56)
        s.note(9, 41, b + 2, 0.3, 46)
        s.note(9, 43, b + 1.56, 0.25, 32)
        if bar < 3:
            s.note(9, 54, b + 1, 0.25, 34)
            s.note(9, 54, b + 3, 0.25, 36)
    # A celesta echo of the motif's head as the answer lands.
    t = 13.0
    for pt, d in M.realise(M.HEAD, G + 12, "major"):
        s.note(7, pt, t, 1.2, 52)
        t += d
    return s, 12.4


STINGERS = {
    "region_opened": region_opened,
    "dream_done": dream_done,
    "power_unlocked": power_unlocked,
    "era_complete": era_complete,
    "era2_begin": era2_begin,
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
