"""Title theme: "The Hand Remembers".

The hand motif in D major, gentle and a little nostalgic: a harp waltz
accompaniment, warm strings, flute and oboe trading the motif, a soft choir
at the peak and a music box at the start and end.

3/4 at 90 bpm, 56 bars = 168 beats = exactly 112 s (4,939,200 samples).
Loops seamlessly from bar 56 back to bar 0.

Run:  python3 tools/music/title.py
"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
from common import GM, SR, Song, dbfs, out_path, peak, render_song, seam_loop, write_ogg  # noqa: E402
import motif as M  # noqa: E402

BPM, BPB, BARS = 90, 3, 56
N = int(round(BARS * BPB * 60 / BPM * SR))
KEY, SCALE = 62, "major"

PROG = [
    [0, 3, 0, 4],
    [0, 5, 3, 4],
    [0, 5, 3, 0],
    [5, 2, 3, 4],
    [3, 4, 0, 5],
    [3, 0, 1, 4],
    [0, 3, 0, 4],
]
CHORDS = [c for sec in PROG for c in sec]


def bt(bar, beat=0.0):
    return bar * BPB + beat


def p(deg, octave=0):
    return M.pitch(deg, KEY, SCALE) + 12 * octave


def play(s, ch, phrase, t, key, shift=0, vel=78, rnd=None, swell=True):
    for pt, d in M.realise(phrase, key, SCALE, shift):
        if pt is not None:
            v = vel + (rnd.randint(-5, 5) if rnd else 0)
            s.note(ch, pt, t, d - 0.08, v)
            if swell and d >= 2:
                s.ramp(ch, 11, 96, 127, t, t + d * 0.4, 6)
                s.ramp(ch, 11, 127, 92, t + d * 0.6, t + d - 0.1, 6)
        t += d
    return t


def build():
    rnd = random.Random(3)
    s = Song(BPM, BPB)
    HARP, STR, FL, OB, CHOIR, BOX, CL, BASS = 0, 1, 2, 3, 4, 5, 6, 7
    s.program(HARP, GM["harp"], vol=84, pan=44, reverb=70)
    s.program(STR, GM["slow_strings"], vol=74, reverb=85)
    s.program(FL, GM["flute"], vol=94, pan=70, reverb=75)
    s.program(OB, GM["oboe"], vol=80, pan=56, reverb=75)
    s.program(CHOIR, GM["oohs"], vol=62, reverb=95)
    s.program(BOX, GM["music_box"], vol=74, pan=84, reverb=85)
    s.program(CL, GM["clarinet"], vol=76, pan=60, reverb=75)
    s.program(BASS, GM["cello"], vol=72, pan=64, reverb=60)

    # Accompaniment: harp waltz (root, then chord tones up), strings, cello roots.
    for bar in range(BARS):
        sec = bar // 8
        deg = CHORDS[bar // 2]
        b = bt(bar)
        root = p(deg, -2)
        if root > 50:
            root -= 12
        s.note(HARP, root + 12, b, 1.8, 58)
        up = [p(deg + 2, -1), p(deg + 4, -1), p(deg + 7, -1)] if bar % 2 == 0 else \
             [p(deg + 4, -1), p(deg + 7, -1), p(deg + 9, -1)]
        for k, n in enumerate(up[:2] if sec in (0, 6) else up):
            s.note(HARP, n, b + 1 + k * (0.5 if sec not in (0, 6) else 1.0), 1.4, 44 + rnd.randint(-5, 5))
        if bar % 2 == 0:
            if sec != 0 or bar >= 4:
                s.chord(STR, [p(deg, -1), p(deg + 2, -1), p(deg + 4, -1)], b, 6, 50 if sec != 4 else 62)
                s.ramp(STR, 11, 70, 115, b, b + 3, 6)
                s.ramp(STR, 11, 115, 80, b + 3, b + 6, 6)
            s.note(BASS, root, b, 5.8, 56 if sec not in (0, 6) else 46)

    fl = KEY + 12
    # S0: music box glimmer of the motif head.
    play(s, BOX, M.HEAD + [(1, 1.0), (0, 2.0)], bt(4, 2), KEY + 12, vel=60, swell=False)
    # S1: the call and its answer.
    play(s, FL, M.MOTIF, bt(8, 2), fl, vel=80, rnd=rnd)
    play(s, FL, [(4, 1), (3, .5), (2, .5), (1, 1), (2, 1), (0, 3)], bt(12, 2), fl, vel=76, rnd=rnd)
    # S2: oboe takes it a step higher, the flute replies.
    play(s, OB, M.MOTIF, bt(16, 2), KEY, shift=1, vel=76, rnd=rnd)
    play(s, FL, [(5, 1), (4, .5), (3, .5), (2, 1), (1, 1), (0, 3)], bt(20, 2), fl, vel=74, rnd=rnd)
    # S3: wandering bridge (the remembering).
    play(s, FL, [(5, 1.5), (4, .5), (2, 1), (4, 2), (3, 1), (2, 1.5), (1, .5), (0, 1), (1, 3)], bt(24, 2), fl, vel=72, rnd=rnd)
    play(s, CL, M.TAIL, bt(29, 0), KEY, vel=62, rnd=rnd)
    # S4: the motif grown to the octave, choir underneath.
    play(s, FL, M.GROWN + [(6, 1), (4, 1), (5, 1), (4, 3)], bt(32, 2), fl, vel=86, rnd=rnd)
    play(s, OB, M.GROWN, bt(36, 2), KEY, vel=64, rnd=rnd)
    for bar in range(32, 40, 2):
        deg = CHORDS[bar // 2]
        s.chord(CHOIR, [p(deg + 2, -1), p(deg + 4, -1), p(deg, 0)], bt(bar), 5.8, 54)
    # S5: the answer, falling home, clarinet low.
    play(s, FL, M.ANSWER, bt(40, 2), fl, vel=74, rnd=rnd)
    play(s, CL, M.MOTIF, bt(44, 2), KEY - 12, vel=60, rnd=rnd)
    # S6: music box reprise, thinning toward the loop.
    play(s, BOX, M.MOTIF, bt(48, 2), KEY + 12, vel=58, swell=False)
    play(s, BOX, [(1, 1), (0, 2)], bt(52, 2), KEY + 12, vel=50, swell=False)
    return s


def main():
    raw = render_song(build(), tail_beats=10, keep_mid=out_path("tools", "music", "midi", "title.mid"))
    a = seam_loop(raw, N)
    a *= 10 ** (-1.0 / 20) / peak(a)
    write_ogg(out_path("assets", "audio", "music", "title.ogg"), a)
    print(f"  title: {N / SR:.3f}s, peak {dbfs(peak(a)):.2f} dBFS")


if __name__ == "__main__":
    main()
