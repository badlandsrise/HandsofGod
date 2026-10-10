"""Era 1 adaptive piece: "First Fire".

A calm, warm, slightly mysterious piece for a primitive tribe. D dorian,
3/4 at 84 bpm, 96 bars (288 beats = exactly 205.714 s = 9,072,000 samples).

Stems (all the same length, all loop seamlessly at bar 96 -> bar 0):
  base    warm drone pad, low strings, cello on the chord roots
  rhythm  hand drums (congas/bongos), frame drum, shaker
  melody  the lone pan flute carrying the hand motif
  colour  kalimba sparkle and echoes, a soft choir in a few sections
  tense   threat variant of rhythm: taiko and low toms in a faster 6/8
          pulse, timpani on the roots. No melody.

Run:  python3 tools/music/era1.py
"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
from common import GM, SR, Song, normalise, out_path, peak, render_song, seam_loop, write_ogg, dbfs  # noqa: E402
import motif as M  # noqa: E402

BPM = 84
BPB = 3
BARS = 96
BEATS = BARS * BPB
N = int(round(BEATS * 60 / BPM * SR))  # 9,072,000
KEY = 62          # D4
SCALE = "dorian"

# Two-bar chords, by section of 8 bars. Degrees: 0=i(Dm) 6=VII(C) 3=IV(G) 4=v(Am) 2=III(F)
PROG = [
    [0, 0, 6, 0],  # 0  intro
    [0, 6, 0, 3],  # 1  first call
    [0, 6, 2, 3],  # 2
    [0, 4, 6, 0],  # 3  breath
    [2, 6, 0, 3],  # 4  motif grows a third
    [0, 4, 2, 6],  # 5
    [0, 0, 3, 3],  # 6  break
    [0, 6, 0, 3],  # 7  low and intimate
    [2, 6, 0, 4],  # 8  build
    [2, 3, 0, 6],  # 9  climax
    [0, 4, 6, 0],  # 10 settling
    [0, 6, 3, 0],  # 11 outro -> loops to intro
]
CHORDS = [c for sec in PROG for c in sec]  # 48 chords x 2 bars


def bt(bar, beat=0.0):
    """Absolute beat of (bar, beat-in-bar)."""
    return bar * BPB + beat


def p(deg, octave=0, key=KEY):
    return M.pitch(deg, key, SCALE) + 12 * octave


def chord_at(bar):
    return CHORDS[(bar // 2) % len(CHORDS)]


# --------------------------------------------------------------- base
def build_base():
    s = Song(BPM, BPB)
    s.program(0, GM["pad_warm"], vol=78, reverb=70, chorus=30)
    s.program(1, GM["slow_strings"], vol=72, pan=50, reverb=80)
    s.program(2, GM["cello"], vol=70, pan=76, reverb=60)
    # Drone: D2 + A2 pad, restruck every 8 bars (pads swell, so it feels continuous).
    for sec in range(12):
        b0 = bt(sec * 8)
        s.note(0, 38, b0, 24, 62)
        s.note(0, 45, b0, 24, 52)
        if sec in (2, 5, 8, 9):  # open fifth higher, a little light in the middle sections
            s.note(0, 57, b0 + 3, 21, 40)
    # Strings: the chord, voiced low and close, a slow swell per chord.
    for i, deg in enumerate(CHORDS):
        b0 = bt(i * 2)
        sec = i // 4
        if sec == 0 and i < 2:
            continue  # the very start is drone alone
        voicing = [p(deg, -1), p(deg + 2, -1), p(deg + 4, -1)]
        voicing = [v if v >= 50 else v + 12 for v in voicing]
        voicing = [v if v <= 66 else v - 12 for v in voicing]
        vel = 46 if sec in (0, 6, 11) else (62 if sec == 9 else 54)
        s.chord(1, sorted(set(voicing)), b0, 6, vel)
        s.ramp(1, 11, 70, 120, b0, b0 + 2.5, 8)
        s.ramp(1, 11, 120, 85, b0 + 3.5, b0 + 6, 8)
        # Cello: chord root, long; moves a little in later sections.
        root = p(deg, -2)
        if root > 50:
            root -= 12
        if sec in (0, 6) and i % 2:
            continue
        s.note(2, root, b0, 5.75 if sec not in (4, 8, 9) else 2.9, 58)
        if sec in (4, 8, 9):
            s.note(2, p(deg + 4, -2) if p(deg + 4, -2) <= 52 else p(deg + 4, -3), b0 + 3, 2.9, 50)
    return s


# --------------------------------------------------------------- rhythm
def build_rhythm():
    rnd = random.Random(11)
    s = Song(BPM, BPB)
    ch = 9
    s.program(ch, 0, vol=96, reverb=45)
    LOW_CONGA, OPEN_CONGA, MUTE_CONGA, HI_BONGO, LOW_BONGO = 64, 63, 62, 60, 61
    FRAME, FRAME2, SHAKER, CABASA = 41, 43, 70, 69

    def hit(n, b, v):
        s.note(ch, n, b + rnd.uniform(-0.012, 0.012), 0.25, v + rnd.randint(-6, 6))

    # Density per section: 0 heartbeat, 1 light, 2 full, 3 full + shaker, 4 fullest
    dens = [0, 1, 2, 2, 3, 2, 0, 1, 3, 4, 2, 0]
    for bar in range(BARS):
        sec, sbar = divmod(bar, 8)
        d = dens[sec]
        b = bt(bar)
        # Frame drum heartbeat: always there, the tribe's pulse.
        if d == 0:
            if sbar % 2 == 0:
                hit(FRAME, b, 58)
                hit(FRAME, b + 2.5, 34)
            else:
                hit(FRAME2, b, 40)
        else:
            hit(FRAME, b, 64)
        if d >= 1:
            hit(LOW_CONGA, b + 2, 46)
            if sbar % 2 == 1:
                hit(MUTE_CONGA, b + 1.5, 34)
        if d >= 2:
            hit(OPEN_CONGA, b + 1, 52)
            hit(MUTE_CONGA, b + 1.5, 36)
            if sbar % 4 == 3:
                hit(HI_BONGO, b + 2.5, 40)
            if sbar % 4 == 1:
                hit(LOW_BONGO, b + 2.5, 38)
        if d >= 3:
            for e in range(6):
                hit(SHAKER, b + e * 0.5, 30 if e % 2 else 40)
        if d >= 4:
            hit(FRAME2, b + 2, 48)
            hit(HI_BONGO, b + 0.5, 34)
        # Fills at the end of each section (except the quiet ones).
        if sbar == 7 and d >= 1:
            for k, n in enumerate([HI_BONGO, HI_BONGO, LOW_BONGO, OPEN_CONGA, LOW_CONGA]):
                hit(n, b + 0.5 + k * 0.5, 40 + k * 5)
        if sbar == 7 and d == 0 and sec != 11:
            hit(CABASA, b + 2, 30)
    return s


# --------------------------------------------------------------- tense
def build_tense():
    rnd = random.Random(23)
    s = Song(BPM, BPB)
    s.program(9, 0, vol=100, reverb=40)
    s.program(0, GM["taiko"], vol=96, reverb=50)
    s.program(1, GM["timpani"], vol=88, reverb=55)
    s.program(2, GM["contrabass"], vol=70, reverb=40)
    LOW_TOM, FLOOR, FLOOR2, LOW_CONGA, MUTE_CONGA = 45, 41, 43, 64, 62

    def hit(ch, n, b, v, dur=0.25):
        s.note(ch, n, b + rnd.uniform(-0.008, 0.008), dur, v + rnd.randint(-5, 5))

    for bar in range(BARS):
        sec, sbar = divmod(bar, 8)
        b = bt(bar)
        deg = chord_at(bar)
        root = p(deg, -3)
        while root > 45:
            root -= 12
        while root < 36:
            root += 12
        # Driving 6/8 pulse: six eighths, accents on 1 and 4.
        for e in range(6):
            v = 70 if e in (0, 3) else 38
            hit(9, FLOOR if e in (0, 3) else MUTE_CONGA, b + e * 0.5, v)
        hit(0, 41, b, 80, 0.5)               # taiko low
        hit(0, 48, b + 1.5, 58, 0.5)
        if sbar % 2 == 1:
            hit(0, 43, b + 2.5, 52, 0.5)
        # Timpani on the roots, a swelling roll every 4 bars.
        if sbar % 4 == 0:
            hit(1, root, b, 72, 2)
        if sbar % 4 == 3:
            for k in range(12):
                hit(1, root, b + k * 0.25, 30 + k * 4, 0.25)
        # Low pulsing contrabass ostinato on the root: dark, unsettled.
        for e in (0, 1, 3, 4):
            hit(2, root, b + e * 0.5, 54 if e in (0, 3) else 40, 0.4)
        if sbar == 7:
            for k in range(8):
                hit(9, LOW_TOM if k < 4 else FLOOR2, b + 1 + k * 0.25, 44 + k * 4)
    return s


# --------------------------------------------------------------- melody
# Phrases: (bar, beat, phrase, scale-step shift, octave)
A = M.MOTIF + [(None, 3)]
B = [(4, 1), (3, .5), (2, .5), (1, 1), (2, 1), (0, 2)]
C = [(-3, 1), (0, 1.5), (1, .5), (2, 1), (4, 1.5), (5, .5), (4, 1), (2, 1), (1, 1), (2, 3)]
D = [(2, 1), (1, .5), (0, .5), (-1, 1), (-3, 3)]
E = M.GROWN + [(6, 1), (4, 1), (5, 1), (4, 3)]
F = [(4, .5), (5, .5), (4, 1), (2, 1), (1, 1), (0, 2)]
G = M.HEAD + [(1, 1), (0, 4)]
H = M.TAIL + [(5, 1), (4, 1), (2, 1), (1, 3)]

MELODY = [
    (8, 2, A, 0, 0), (12, 2, B, 0, 0),            # call ... and its answer
    (16, 2, C, 0, 0),                              # the motif wanders on
    (21, 2, D, 0, 0),
    (32, 2, A, 2, 0), (36, 2, D, 2, 0),           # motif grows a third
    (40, 0, H, 0, 0), (44, 2, F, 0, 0),
    (56, 2, A, 0, -1), (61, 0, G, 0, -1),         # low and intimate
    (64, 2, C, 1, 0), (69, 0, D, 0, 0),
    (72, 2, E, 0, 0), (77, 0, F, 0, 0),           # the fullest statement
    (80, 2, A, 0, 0), (84, 2, G, 0, 0),           # settling home
]


def build_melody():
    rnd = random.Random(5)
    s = Song(BPM, BPB)
    s.program(0, GM["pan_flute"], vol=92, pan=60, reverb=75, chorus=10)
    for bar, beat, phrase, shift, octv in MELODY:
        t = bt(bar, beat)
        notes = M.realise(phrase, KEY + 12 * (1 + octv), SCALE, shift)
        for i, (pt, d) in enumerate(notes):
            if pt is not None:
                vel = 72 + rnd.randint(-6, 6) + (8 if d >= 2 else 0)
                gap = 0.06 if d < 1 else 0.12   # breaths between notes
                s.note(0, pt, t, d - gap, vel)
                if d >= 2:  # breath swell on long notes
                    s.ramp(0, 11, 95, 127, t, t + d * 0.4, 6)
                    s.ramp(0, 11, 127, 90, t + d * 0.6, t + d - gap, 6)
                else:
                    s.cc(0, 11, 115, t)
            t += d
    return s


# --------------------------------------------------------------- colour
def build_colour():
    rnd = random.Random(7)
    s = Song(BPM, BPB)
    s.program(0, GM["kalimba"], vol=84, pan=82, reverb=70)
    s.program(1, GM["oohs"], vol=60, pan=44, reverb=90)
    s.program(2, GM["kalimba"], vol=70, pan=40, reverb=80)
    # Echoes: kalimba answers the flute with motif fragments (call and response).
    echoes = [
        (11, 0, M.HEAD, 0), (15, 0, M.TAIL, 0), (20, 1, M.HEAD, 2),
        (26, 2, M.MOTIF, 0), (35, 0, M.TAIL, 2), (47, 0, M.HEAD, 0),
        (51, 2, M.MOTIF, -1), (59, 0, M.ANSWER, 0), (67, 0, M.TAIL, 1),
        (75, 0, M.HEAD, 4), (83, 0, M.TAIL, 0), (90, 2, M.MOTIF, 0),
    ]
    for bar, beat, ph, shift in echoes:
        t = bt(bar, beat)
        for pt, d in M.realise(ph, KEY + 12, SCALE, shift):
            if pt is not None:
                s.note(2, pt, t, max(d, 1.0), 58 + rnd.randint(-6, 6))
            t += d
    # Sparkle: sparse rising chord-tone arpeggios, density varies by section.
    dens = [0.25, 0.15, 0.25, 0.45, 0.3, 0.35, 0.55, 0.15, 0.4, 0.5, 0.3, 0.3]
    for bar in range(BARS):
        sec, sbar = divmod(bar, 8)
        if rnd.random() > dens[sec]:
            continue
        deg = chord_at(bar)
        tones = [deg, deg + 2, deg + 4, deg + 7]
        start = rnd.choice([0, 0.5, 1, 1.5])
        n = rnd.choice([2, 3, 3, 4])
        for k in range(n):
            pt = p(tones[k % len(tones)], 1)
            s.note(0, pt, bt(bar, start + k * 0.5), 1.5, 46 + rnd.randint(-8, 6) - k * 3)
    # Soft choir in the breathing sections.
    for sec in (3, 6, 9):
        for i in range(4):
            bar = sec * 8 + i * 2
            deg = chord_at(bar)
            tones = [p(deg, 0), p(deg + 2, 0), p(deg + 4, -1)]
            b0 = bt(bar)
            s.chord(1, tones, b0, 5.8, 50)
            s.ramp(1, 11, 40, 110, b0, b0 + 3, 6)
            s.ramp(1, 11, 110, 40, b0 + 3, b0 + 5.8, 6)
    return s


# Stem balance (dB) applied after rendering, so each layer sits right in the mix.
MIX_DB = {"base": -4.0, "rhythm": 2.0, "melody": 1.0, "colour": 8.0, "tense": -5.0}

STEMS = {
    "base": build_base,
    "rhythm": build_rhythm,
    "melody": build_melody,
    "colour": build_colour,
    "tense": build_tense,
}


def main():
    outdir = out_path("assets", "audio", "music", "era1")
    middir = out_path("tools", "music", "midi", "era1")
    audio = {}
    for name, fn in STEMS.items():
        raw = render_song(fn(), tail_beats=10, keep_mid=os.path.join(middir, name + ".mid"))
        audio[name] = seam_loop(raw, N) * 10 ** (MIX_DB[name] / 20)
        print(f"  {name}: rendered {len(raw) / SR:.2f}s -> loop {N / SR:.3f}s")
    full = audio["base"] + audio["rhythm"] + audio["melody"] + audio["colour"]
    threat = audio["base"] + audio["tense"] + audio["colour"]
    everything = full + audio["tense"]
    ref = max(peak(full), peak(threat), peak(everything) / 1.12)  # all five at once stays < 0 dBFS
    g = 10 ** (-1.0 / 20) / ref
    for name, a in audio.items():
        write_ogg(os.path.join(outdir, name + ".ogg"), a * g)
    print(f"  mix peak {dbfs(peak(full * g)):.2f} dBFS, threat mix {dbfs(peak(threat * g)):.2f} dBFS")


if __name__ == "__main__":
    main()
