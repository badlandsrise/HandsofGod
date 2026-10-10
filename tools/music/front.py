"""Front-end audio: the studio sting and the intro underscore.

  studio_sting.ogg  ~3.6 s  "Badlandsrise Game Studio": a low warm swell under
                            a harp run that climbs like the sun over the ridge,
                            a soft timpani and brass arrival as it clears the
                            mesa, then bells and choir ringing out on D.
  intro.ogg         ~62 s   the opening before the storm night, cued to the
                            intro script (scripts/front/intro.gd) second by
                            second (60 bpm, so one beat is one second):
                              0-14   the wild valley: a lone pan flute over a drone
                             14-24   the storm gathers: low strings, a timpani roll
                             24-35   the god notices them: the motif's head on
                                     celesta, hesitant, twice
                             35-45   the hand comes down and they cower: a cold
                                     cluster swells, then hushes
                             45-62   tender: the whole hand motif on flute over
                                     warm strings, ending open on the fifth, so
                                     Era 1's stems can take over

Run:  python3 tools/music/front.py [studio_sting|intro]
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from common import GM, SR, Song, dbfs, fit_oneshot, normalise, out_path, peak, render_song, write_ogg  # noqa: E402
import motif as M  # noqa: E402

KEY = 62  # D


def P(deg, octave=0, scale="major"):
    return M.pitch(deg, KEY, scale) + 12 * octave


def play(s, ch, phrase, t, key=KEY, scale="major", shift=0, vel=80, legato=0.95, minlen=0.0):
    for pt, d in M.realise(phrase, key, scale, shift):
        if pt is not None:
            s.note(ch, pt, t, max(d * legato, minlen), vel)
        t += d
    return t


def studio_sting():
    s = Song(60, 4)      # one beat = one second
    PAD, HARP, TIMP, BRASS, BELL, CHOIR, STR, TAIKO = 0, 1, 2, 3, 4, 5, 6, 7
    s.program(PAD, GM["pad_warm"], vol=92, reverb=90)
    s.program(HARP, GM["harp"], vol=88, pan=48, reverb=85)
    s.program(TIMP, GM["timpani"], vol=96, reverb=70)
    s.program(BRASS, GM["horn"], vol=84, pan=58, reverb=85)
    s.program(BELL, GM["bells"], vol=74, pan=80, reverb=95)
    s.program(CHOIR, GM["choir"], vol=70, reverb=100)
    s.program(STR, GM["slow_strings"], vol=82, reverb=90)
    s.program(TAIKO, GM["taiko"], vol=80, reverb=70)
    # the dark before sunrise: a low open fifth swelling
    s.chord(PAD, [P(0, -2), P(4, -2), P(0, -1)], 0.0, 3.4, 70)
    s.ramp(PAD, 11, 30, 120, 0.0, 1.2, 16)
    s.chord(STR, [P(0, -2), P(4, -2)], 0.1, 3.3, 54)
    s.ramp(STR, 11, 20, 110, 0.1, 1.2, 16)
    # the sun climbs: a harp run up the D major pentatonic
    run = [0, 1, 2, 4, 5, 7, 8, 9, 11, 12]
    for k, d in enumerate(run):
        s.note(HARP, P(d, -1), 0.25 + k * 0.095, 2.4, 46 + k * 4)
    # the arrival as it clears the ridge
    s.note(TIMP, 38, 1.18, 1.6, 92)
    s.note(TAIKO, 41, 1.18, 0.8, 70)
    s.chord(BRASS, [P(0, -1), P(4, -1), P(0, 0)], 1.2, 2.2, 78)
    s.ramp(BRASS, 11, 127, 70, 1.6, 3.4, 12)
    s.chord(STR, [P(0, -1), P(2, -1), P(4, -1), P(1, 0)], 1.2, 2.2, 70)
    # bells: the rising D - A - D, and the choir's warm add9
    for k, d in enumerate([0, 4, 7]):
        s.note(BELL, P(d, 0), 1.25 + k * 0.22, 2.0, 70 - k * 4)
    s.chord(CHOIR, [P(0, -1), P(4, -1), P(1, 0), P(2, 0)], 1.3, 2.1, 60)
    return s, 3.6


def intro():
    s = Song(60, 4)      # one beat = one second, cued to scripts/front/intro.gd
    FL, DRONE, LOW, TIMP, CEL, CLUSTER, STR, HARP, OB = 0, 1, 2, 3, 4, 5, 6, 7, 8
    s.program(FL, GM["pan_flute"], vol=92, pan=60, reverb=95)
    s.program(DRONE, GM["pad_new_age"], vol=70, reverb=95)
    s.program(LOW, GM["tremolo"], vol=78, reverb=85)
    s.program(TIMP, GM["timpani"], vol=84, reverb=80)
    s.program(CEL, GM["celesta"], vol=86, pan=70, reverb=95)
    s.program(CLUSTER, GM["slow_strings"], vol=80, reverb=95)
    s.program(STR, GM["strings"], vol=84, reverb=90)
    s.program(HARP, GM["harp"], vol=80, pan=44, reverb=85)
    s.program(OB, GM["flute"], vol=92, pan=64, reverb=90)
    dor = "dorian"
    # 0-14: the wild valley -- a drone and a lone flute, free and unhurried
    s.chord(DRONE, [P(0, -2, dor), P(4, -2, dor)], 0.0, 23.0, 60)
    s.ramp(DRONE, 11, 20, 100, 0.0, 4.0, 16)
    s.ramp(DRONE, 11, 100, 40, 18.0, 23.0, 12)
    t = 2.0
    for phrase in ([(4, 1.5), (3, 0.5), (2, 2.0)], [(0, 1.0), (2, 1.0), (1, 2.5)], [(-1, 1.0), (0, 3.0)]):
        t = play(s, FL, phrase, t, KEY + 12, dor, vel=70, minlen=0.6) + 0.8
    # 14-24: the storm gathers
    s.chord(LOW, [P(0, -2, dor), P(2, -2, dor)], 14.0, 10.5, 56)
    s.ramp(LOW, 11, 20, 118, 14.0, 21.0, 20)
    s.ramp(LOW, 11, 118, 50, 22.0, 24.5, 8)
    for k in range(40):
        s.note(TIMP, 38, 17.0 + k * 0.12, 0.13, 24 + int(k * 1.6))
    s.note(TIMP, 38, 21.9, 2.0, 92)
    s.chord(CLUSTER, [P(0, -1, dor), P(5, -2, dor)], 18.0, 6.0, 52)
    # 24-35: the god notices them -- the motif's head, hesitant, twice
    s.chord(DRONE, [P(0, -1, "major"), P(4, -1, "major")], 24.0, 11.0, 52)
    s.ramp(DRONE, 11, 30, 90, 24.0, 27.0, 10)
    t = play(s, CEL, M.HEAD, 25.0, KEY + 12, "major", vel=66, minlen=1.2)
    play(s, CEL, M.HEAD, t + 2.6, KEY + 12, "major", vel=60, minlen=1.2)
    for k, d in enumerate([0, 4, 7]):
        s.note(HARP, P(d, -1), 31.5 + k * 0.3, 3.0, 50)
    # 35-45: the hand comes down; they cower -- a cold cluster, then hush
    s.chord(CLUSTER, [P(0, -1), P(1, -1), P(3, -1), P(4, -2)], 35.0, 8.5, 58)
    s.ramp(CLUSTER, 11, 20, 122, 35.0, 39.5, 16)
    s.ramp(CLUSTER, 11, 122, 10, 40.0, 43.5, 12)
    s.note(TIMP, 33, 39.4, 2.0, 70)
    s.note(LOW, P(0, -2), 36.0, 7.0, 52)
    # 45-62: tender -- the hand motif in full, ending open on the fifth
    prog = [(0, 45.0, 4.0), (5, 49.0, 4.0), (3, 53.0, 4.0), (4, 57.0, 5.0)]
    for deg, b, d in prog:
        s.chord(STR, [P(deg, -2), P(deg, -1), P(deg + 2, -1), P(deg + 4, -1)], b, d, 56)
    s.ramp(STR, 11, 30, 100, 45.0, 49.0, 12)
    s.ramp(STR, 11, 100, 70, 58.0, 62.0, 8)
    for k, d in enumerate([0, 2, 4, 7, 9]):
        s.note(HARP, P(d, -1), 45.0 + k * 0.25, 3.0, 54)
    t = play(s, OB, M.MOTIF, 47.5, KEY + 12, "major", vel=74, minlen=0.8)   # ~6 beats
    play(s, OB, [(4, 2.0), (2, 1.0), (4, 4.0)], t + 1.0, KEY + 12, "major", vel=66, minlen=1.0)
    play(s, CEL, M.TAIL, 58.0, KEY + 24, "major", vel=48, minlen=1.2)
    return s, 62.0


PIECES = {"studio_sting": studio_sting, "intro": intro}


def main():
    outdir = out_path("assets", "audio", "music")
    only = sys.argv[1:]
    for name, fn in PIECES.items():
        if only and name not in only:
            continue
        song, secs = fn()
        raw = render_song(song, tail_beats=4)
        a = fit_oneshot(raw, int(secs * SR), fade_s=min(2.5, secs * 0.3))
        a = normalise(a, -3.5 if name == "studio_sting" else -3.0)
        write_ogg(os.path.join(outdir, name + ".ogg"), a)
        print(f"  {name}: {secs:.2f}s peak {dbfs(peak(a)):.1f} dBFS")


if __name__ == "__main__":
    main()
