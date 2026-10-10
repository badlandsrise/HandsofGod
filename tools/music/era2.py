"""Era 2 adaptive piece: "Long Furrows".

A settled farming village: warmer and fuller than Era 1's lone flute. The
hand motif comes back as a fiddle tune with a recorder answering it, over a
lute-like fingerpicked guitar, light strings, cello, frame drum and
tambourine.

G major with mixolydian colour (the F-major bVII chord, an F natural in the
tune over it), 4/4 at 90 bpm with a light swing on the eighths. Era 1 is a
3/4 lilt in D dorian; this is a square, walking common time a fourth higher
so the change of era is heard at once. 80 bars (320 beats = exactly
213.333 s = 9,408,000 samples).

Form (8-bar sections):
  0 intro      lute and strings, the fiddle tuning in; the recorder
               half-remembers the motif
  1 A          the village tune: the motif re-barred in 4/4, leaping wider
  2 A'         the tune again with fiddle turns and a new cadence
  3 B          recorder calls the motif from C, fiddle answers (F natural)
  4 B'         fiddle and recorder together, the opening reaching F
  5 interlude  the motif augmented on recorder, long and slow
  6 develop    motif in sequence, cut into quick fiddle figures
  7 build      rising fiddle against a falling recorder descant
  8 climax     the motif grown to the octave, the tune in two parts
  9 outro      fragments, then the motif's question on D -> loops to G

Stems (all the same length, all loop seamlessly at bar 80 -> bar 0):
  base    light strings, cello, fingerpicked nylon guitar ("lute")
  rhythm  frame drum, tambourine, shaker, strummed steel guitar, pizz bass
  melody  fiddle lead, recorder answers and harmonies
  colour  harp sparkle and motif echoes, clarinet counter-line, soft choir
  tense   threat variant of rhythm: straight 3+3+2 toms, taiko, timpani,
          contrabass ostinato, low tremolo strings. No melody.

Run:  python3 tools/music/era2.py
"""
import os
import random
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from common import GM, SR, Song, dbfs, lufs, out_path, peak, read_audio, render_song, seam_loop, write_ogg  # noqa: E402
import motif as M  # noqa: E402

BPM = 90
BPB = 4
BARS = 80
BEATS = BARS * BPB
N = int(round(BEATS * 60 / BPM * SR))  # 9,408,000
KEY = 67          # G4
SCALE = "major"
MIXO = "mixolydian"
SWING = 0.06      # offbeat eighths land a little late (about 56:44)

# Chords: name -> (semitones above G, triad intervals)
CH = {
    "G": (0, (0, 4, 7)), "C": (5, (0, 4, 7)), "D": (7, (0, 4, 7)), "F": (10, (0, 4, 7)),
    "Em": (9, (0, 3, 7)), "Am": (2, (0, 3, 7)), "Bm": (4, (0, 3, 7)),
}
# One chord per bar; "Am|D" splits the bar in half.
HARM = [
    "G G C G Em C D D",           # 0 intro
    "G C G D Em C D G",           # 1 A
    "G C G D Em C Am|D G",        # 2 A'
    "C G Am Em F C D D",          # 3 B
    "C G Am Em F G C|D G",        # 4 B'
    "Em C G D Em C Am D",         # 5 interlude
    "C F C G Am F G G",           # 6 develop
    "Em Bm C G Am Em F D",        # 7 build
    "G C G D Em C Am|D G",        # 8 climax
    "C G Am G C G D D",           # 9 outro -> loops to G
]
BAR_CHORDS = [c for sec in HARM for c in sec.split()]
assert len(BAR_CHORDS) == BARS


def bt(bar, beat=0.0):
    return bar * BPB + beat


def sw(beat):
    """Swing: an offbeat eighth lands SWING beats late."""
    f = beat % 1.0
    return beat + SWING if abs(f - 0.5) < 1e-6 else beat


def chords_in(bar):
    """[(beat_in_bar, beats, chord_name)] for a bar."""
    parts = BAR_CHORDS[bar % BARS].split("|")
    d = BPB / len(parts)
    return [(i * d, d, c) for i, c in enumerate(parts)]


def root_pc(name):
    return (KEY + CH[name][0]) % 12


def tones(name):
    off, iv = CH[name]
    return [(KEY + off + i) % 12 for i in iv]


def in_range(pc, lo):
    """Lowest pitch of pitch class pc that is >= lo."""
    return lo + (pc - lo) % 12


def voicing(name, lo=55, hi=72, n=4):
    """Close-ish voicing of a chord inside [lo, hi]."""
    ts = tones(name)
    out = sorted({in_range(pc, lo) for pc in ts})
    k = 0
    while len(out) < n and k < len(out):
        v = out[k] + 12
        if v <= hi and v not in out:
            out.append(v)
        k += 1
    return sorted(out)[:n]


def section_of(bar):
    return bar // 8, bar % 8


# --------------------------------------------------------------- base
def build_base():
    rnd = random.Random(21)
    s = Song(BPM, BPB)
    s.program(0, GM["slow_strings"], vol=70, pan=58, reverb=72, chorus=20)
    s.program(1, GM["cello"], vol=74, pan=74, reverb=55)
    s.program(2, GM["nylon"], vol=88, pan=46, reverb=50)
    s.program(3, GM["contrabass"], vol=62, pan=64, reverb=45)
    quiet = (0, 5, 9)
    for bar in range(BARS):
        sec, sbar = section_of(bar)
        b = bt(bar)
        for cb, cd, name in chords_in(bar):
            t0 = b + cb
            # Light strings: close voicing, a slow swell through the chord.
            vel = 40 if sec in quiet else (54 if sec == 8 else 47)
            s.chord(0, voicing(name, 55, 71, 3 if sec in quiet else 4), t0, cd - 0.05, vel)
            s.ramp(0, 11, 72, 118, t0, t0 + cd * 0.55, 6)
            s.ramp(0, 11, 118, 88, t0 + cd * 0.6, t0 + cd - 0.05, 6)
            # Cello: whole-note roots when quiet, a walking two-feel otherwise.
            r = in_range(root_pc(name), 36)
            if sec in quiet or cd < BPB:
                s.note(1, r, t0, cd - 0.1, 56)
            else:
                fifth = r + 7 if r + 7 <= 55 else r - 5
                s.note(1, r, t0, 1.9, 60)
                s.note(1, fifth, t0 + 2, 1.9, 50)
            if sec in (7, 8):
                s.note(3, r - 12 if r - 12 >= 28 else r, t0, cd - 0.1, 50)
        # The "lute": fingerpicked nylon guitar, triangle arpeggio in eighths.
        for cb, cd, name in chords_in(bar):
            r = in_range(root_pc(name), 40)
            third = CH[name][1][1]
            arp = [r, r + 7, r + 12, r + 12 + third, r + 19, r + 12 + third, r + 12, r + 7]
            steps = int(cd * 2)
            sparse = sec in quiet
            for k in range(steps):
                if sparse and k % 2:
                    continue
                pos = b + cb + k * 0.5
                v = 58 if k % 4 == 0 else 44
                v += rnd.randint(-5, 4) - (6 if sparse else 0)
                nd = 1.2 if k == 0 else (0.95 if sparse else 0.6)
                st = sw(pos) + rnd.uniform(-0.01, 0.01)
                s.note(2, arp[k % len(arp)], st, nd, v)
    return s


# --------------------------------------------------------------- rhythm
def build_rhythm():
    rnd = random.Random(31)
    s = Song(BPM, BPB)
    s.program(9, 0, vol=94, reverb=40)
    s.program(0, GM["steel"], vol=70, pan=30, reverb=45)
    s.program(1, GM["pizz"], vol=82, pan=70, reverb=45)
    FRAME_LO, FRAME_HI, FRAME_MID, TAMB, SHAKER, CLAP, RIM = 41, 43, 45, 54, 70, 39, 37

    def hit(n, b, v, d=0.25):
        s.note(9, n, sw(b) + rnd.uniform(-0.012, 0.012), d, v + rnd.randint(-5, 5))

    # 0 none .. 4 fullest, per 8-bar section.
    dens = [1, 2, 2, 3, 3, 1, 2, 3, 4, 1]
    for bar in range(BARS):
        sec, sbar = section_of(bar)
        d = dens[sec]
        b = bt(bar)
        e = [b + k * 0.5 for k in range(8)]
        fill = sbar == 7 and d >= 2 and sec != 9
        # Frame drum (bodhran-like): low on 1 and 3, ghost lifts.
        hit(FRAME_LO, e[0], 66)
        hit(FRAME_LO, e[4], 52 if d >= 2 else 44)
        if d >= 1:
            hit(FRAME_HI, e[3], 28)
            hit(FRAME_HI, e[7], 30)
        if d >= 2:
            hit(FRAME_HI, e[2], 40)
            if not fill:
                hit(FRAME_HI, e[6], 40)
            hit(FRAME_LO, e[5], 30)
            hit(TAMB, e[2], 34)
            hit(TAMB, e[6], 36)
        if d >= 3:
            for k in range(8):
                hit(SHAKER, e[k], 28 if k % 2 == 0 else 20)
            hit(TAMB, e[7], 18)
        if d >= 4:
            hit(CLAP, e[2], 30)
            hit(CLAP, e[6], 32)
            hit(FRAME_LO, e[7], 38)
        if d == 1 and sbar % 2 == 1:
            hit(RIM, e[6], 26)
        if fill:
            for k, n in enumerate([FRAME_HI, FRAME_HI, FRAME_MID, FRAME_LO]):
                s.note(9, n, b + 3 + k * 0.25 + rnd.uniform(-0.01, 0.01), 0.2, 40 + k * 6)
        # Strummed steel guitar: D - D U - U D U.
        for cb, cd, name in chords_in(bar):
            vo = voicing(name, 52, 69, 5)
            pattern = [(0, 50, 1), (1, 44, 1), (1.5, 30, -1), (2.5, 32, -1), (3, 44, 1), (3.5, 30, -1)]
            if d == 1:
                pattern = [(0, 40, 1), (2, 34, 1)]
            for pos, v, way in pattern:
                if pos >= cd:
                    continue
                t0 = sw(b + cb + pos)
                strings = vo if way > 0 else list(reversed(vo))[:3]
                for k, pt in enumerate(strings):
                    s.note(0, pt, t0 + k * (0.025 if way > 0 else 0.015), 0.45, v - k * 2 + rnd.randint(-3, 3))
        # Pizzicato bass bounce in the fuller sections.
        if d >= 3:
            for cb, cd, name in chords_in(bar):
                r = in_range(root_pc(name), 43)
                s.note(1, r, b + cb, 0.5, 64)
                if cd >= 4:
                    s.note(1, r + 7 if r + 7 <= 57 else r - 5, b + cb + 2, 0.5, 54)
                    nxt = chords_in(bar + 1)[0][2]
                    nr = in_range(root_pc(nxt), 43)
                    s.note(1, nr - 1 if nr > r else nr + 2, sw(b + cb + 3.5), 0.4, 44)
    return s


# --------------------------------------------------------------- tense
def build_tense():
    rnd = random.Random(41)
    s = Song(BPM, BPB)
    s.program(9, 0, vol=100, reverb=40)
    s.program(0, GM["taiko"], vol=94, reverb=50)
    s.program(1, GM["timpani"], vol=88, reverb=55)
    s.program(2, GM["contrabass"], vol=74, reverb=40)
    s.program(3, GM["tremolo"], vol=70, pan=54, reverb=60)
    LOW_TOM, FLOOR, FLOOR2, MUTE_CONGA, RIM = 45, 41, 43, 62, 37

    def hit(ch, n, b, v, d=0.25):
        s.note(ch, n, b + rnd.uniform(-0.008, 0.008), d, v + rnd.randint(-4, 4))

    for bar in range(BARS):
        sec, sbar = section_of(bar)
        b = bt(bar)
        # Straight eighths, 3+3+2: urgent against the village's easy swing.
        for k in range(8):
            acc = k in (0, 3, 6)
            hit(9, FLOOR if acc else MUTE_CONGA, b + k * 0.5, 72 if acc else 36)
        hit(0, 41, b, 82, 0.5)
        hit(0, 48, b + 1.5, 60, 0.5)
        hit(0, 43, b + 3, 56 if sbar % 2 else 40, 0.5)
        for cb, cd, name in chords_in(bar):
            r = in_range(root_pc(name), 36)
            if r > 45:
                r -= 12
            if cb == 0 and sbar % 2 == 0:
                hit(1, r, b, 74, 2)
            for k in range(int(cd * 2)):
                v = 58 if k % 3 == 0 else 40
                hit(2, r + (12 if k in (3, 6) else 0), b + cb + k * 0.5, v, 0.4)
            # Low tremolo strings: root and fifth, a swell to each chord.
            s.chord(3, [r + 12, r + 19], b + cb, cd - 0.05, 54)
            s.ramp(3, 11, 50, 115, b + cb, b + cb + cd * 0.8, 6)
        if sbar % 4 == 3:
            r = in_range(root_pc(chords_in(bar)[-1][2]), 36)
            r = r - 12 if r > 45 else r
            for k in range(8):
                hit(1, r, b + 2 + k * 0.25, 30 + k * 6, 0.25)
        if sbar == 7:
            for k in range(8):
                hit(9, LOW_TOM if k < 4 else FLOOR2, b + 2 + k * 0.25, 44 + k * 5)
    return s


# --------------------------------------------------------------- melody
# Phrases are [(degree, beats)] in G major unless tagged "mixo" (F natural).
# The motif in 4/4: an eighth pickup D, then G (dotted) A, B, and the open leap.
A_TUNE = [  # bars 8-15, after a pickup at bar 7 beat 3.5
    (0, 1.5), (1, .5), (2, 1), (4, 1),               # G   the motif, re-barred
    (5, 1.5), (4, .5), (3, 1), (5, 1),               # C
    (4, 1), (2, .5), (1, .5), (0, 1), (2, 1),        # G
    (1, 1), (-1, .5), (-2, .5), (-3, 1.5), (-3, .5),  # D   (last D is the next pickup)
    (0, 1.5), (1, .5), (2, 1), (5, 1),               # Em  the hand opens wider
    (7, 1), (5, .5), (4, .5), (3, 1), (5, 1),        # C
    (4, 1.5), (3, .5), (1, 1), (-1, 1),              # D
    (0, 3), (None, .5), (-3, .5),                    # G   (pickup into A')
]
A2_TUNE = [  # bars 16-23
    (0, 1.5), (1, .5), (2, 1), (4, 1),
    (5, 1), (7, .5), (5, .5), (3, .5), (4, .5), (5, 1),   # a fiddle turn
    (4, 1), (2, .5), (1, .5), (0, 1), (2, 1),
    (1, 1), (-1, .5), (-2, .5), (-3, 1.5), (-3, .5),
    (0, 1.5), (1, .5), (2, 1), (5, 1),
    (7, 1), (5, .5), (4, .5), (3, 1), (5, 1),
    (3, 1), (5, .5), (4, .5), (3, 1), (1, 1),             # Am | D
    (2, 1), (1, .5), (0, 2.5),                             # G
]
B_CALL = [  # recorder, bars 24-27: the motif from C
    (3, 1.5), (4, .5), (5, 1), (7, 1),
    (9, 1.5), (8, .5), (7, 2),
    (5, 1), (8, 1.5), (7, .5), (5, 1),
    (7, 1), (6, .5), (5, .5), (2, 2),
]
B_ANSWER = [  # fiddle, bars 28-31 (bar 28 over F: mixolydian)
    ("mixo", [(3, 1.5), (1, .5), (-1, 1), (1, 1)]),
    (None, [(3, 1.5), (4, .5), (5, 2)]),
    (None, [(4, 1), (5, .5), (6, .5), (8, 2)]),           # the "opening", up to A
    (None, [(6, .5), (7, .5), (8, .5), (6, .5), (4, 1), (1, 1)]),
]
B2_END = [  # bars 36-39 over F G C|D G
    ("mixo", [(3, 1), (1, .5), (3, .5), (6, 2)]),          # reaches F natural
    (None, [(4, 1.5), (2, .5), (0, 2)]),
    (None, [(5, 1), (4, .5), (3, .5), (1, 1), (-1, 1)]),
    (None, [(0, 3), (None, 1)]),
]
# Interlude: the motif augmented on recorder, then its answer, slow.
INTER = [(None, 2), (-3, 2), (0, 3), (1, 1), (2, 2), (4, 4), (None, 2),
         (2, 2), (0, 1), (1, 1), (-2, 3), (0, 1), (1, 2), (3, 1), (2, 1), (1, 3), (None, .5)]
DEVELOP = [  # fiddle, bars 48-55 (after a pickup G at 47.3.5)
    (None, [(3, 1.5), (4, .5), (5, 1), (7, 1)]),            # C   motif from C
    ("mixo", [(6, 1.5), (5, .5), (3, 1), (1, 1)]),          # F
    (None, [(5, .5), (4, .5), (3, .5), (4, .5), (5, 1), (7, 1)]),  # C  cut quick
    (None, [(4, 1.5), (2, .5), (0, 2)]),                    # G
    (None, [(1, 1.5), (2, .5), (3, 1), (5, 1)]),            # Am  motif from A
    ("mixo", [(6, 1), (5, .5), (4, .5), (3, 2)]),           # F
    (None, [(2, .5), (3, .5), (4, 1), (7, 2)]),             # G   the opening
    (None, [(7, 1), (6, .5), (5, .5), (4, 1), (2, 1)]),     # G
]
BUILD = [  # fiddle rising, bars 56-63
    (None, [(2, 1), (5, 1.5), (6, .5), (7, 1)]),
    (None, [(6, 2), (4, 1), (2, 1)]),
    (None, [(3, 1), (5, 1.5), (4, .5), (7, 1)]),
    (None, [(9, 2), (7, .5), (8, .5), (4, 1)]),
    (None, [(8, 1.5), (7, .5), (5, 1), (8, 1)]),
    (None, [(7, 1.5), (6, .5), (5, 1), (2, 1)]),
    ("mixo", [(6, 1.5), (5, .5), (3, 1), (8, 1)]),
    (None, [(8, 1), (6, .5), (5, .5), (4, 1.5), (-3, .5)]),  # pickup into the climax
]
DESCANT = [(2, 4), (-1, 4), (-2, 4), (4, 4), (3, 4), (2, 4), ("mixo", 1, 4), (-1, 2), (1, 2)]
GROWN_BAR = [(0, 1), (1, .5), (2, .5), (4, 1), (7, 1)]      # M.GROWN in one bar of 4/4
OUTRO = [
    (None, 1), (5, 1.5), (4, .5), (3, 1),
    (2, 3), (None, 1),
    (None, 1), (3, 1.5), (2, .5), (1, 1),
    (0, 3), (None, 1),
    (None, 3.5), (-3, .5),
    (0, 1.5), (1, .5), (2, 1), (4, 1),                       # the motif's question...
    (4, 4),                                                  # ...left open on D
]
INTRO_FID = [(None, 2), (-3, 2), (0, 4), (-2, 4), (-3, 3)]   # soft long notes, the fiddle tuning in
INTRO_REC = [(None, 15.5), (-3, .5), (0, 1.5), (1, .5), (2, 1), (5, 1), (4, 1), (3, 3), (1, 4), (None, 3.5)]


def flat(bars):
    """[(scale, phrase)] per bar -> [(degree, beats, scale)]."""
    out = []
    for tag, ph in bars:
        sc = MIXO if tag == "mixo" else SCALE
        out += [(d, b, sc) for d, b in ph]
    return out


def plain(ph, sc=SCALE):
    return [(d, b, sc) for d, b in ph]


def harmonise(notes, t):
    """A second voice above a line: a third where it fits the chord, else a
    fourth, sixth or fifth (the nearest chord tone above). Short notes off the
    beat keep the third, as a folk second part would."""
    out = []
    for d, dur, sc in notes:
        if d is None:
            out.append((d, dur, sc))
            t += dur
            continue
        bar = int(round(t, 3) // BPB)
        bib = t - bar * BPB
        name = [c for cb, cd, c in chords_in(bar) if cb <= bib + 1e-6][-1]
        strong = dur >= 1 or abs(bib - round(bib)) < 1e-6
        pick = 2
        if strong:
            for k in (2, 3, 5, 4):
                if M.pitch(d + k, KEY, sc) % 12 in tones(name):
                    pick = k
                    break
        out.append((d + pick, dur, sc))
        t += dur
    return out


def build_melody():
    rnd = random.Random(55)
    s = Song(BPM, BPB)
    FID, REC = 0, 1
    s.program(FID, GM["fiddle"], vol=96, pan=58, reverb=62, chorus=12)
    s.program(REC, GM["recorder"], vol=80, pan=76, reverb=70)

    def play(ch, t, notes, key, shift=0, vel=74, ornament=False, legato=0.9):
        for d, dur, sc in notes:
            if d is not None:
                pt = M.pitch(d + shift, key, sc)
                st, en = sw(t), sw(t + dur)
                v = vel + rnd.randint(-5, 5) + (6 if dur >= 2 else 0) + (4 if t % 2 == 0 else 0)
                if ornament and dur >= 1 and rnd.random() < 0.35:
                    # a fiddler's cut: the note above, flicked in just before
                    s.note(ch, M.pitch(d + shift + 1, key, sc), st - 0.07, 0.06, v - 18)
                s.note(ch, pt, st + rnd.uniform(-0.01, 0.01), (en - st) * legato, v)
                if dur >= 1.5:
                    s.ramp(ch, 11, 92, 124, st, st + dur * 0.45, 5)
                    s.ramp(ch, 11, 124, 96, st + dur * 0.55, st + dur * legato, 5)
                    s.ramp(ch, 1, 0, 28 if ch == FID else 12, st + 0.3, st + dur * 0.8, 4)
                    s.cc(ch, 1, 0, st + dur)
                else:
                    s.cc(ch, 11, 112, st)
            t += dur
        return t

    hi = KEY + 12
    play(FID, bt(0), plain(INTRO_FID), KEY, vel=50, legato=0.97)
    play(REC, bt(0), plain(INTRO_REC), hi, vel=62)
    play(FID, bt(7, 3.5), plain([(-3, .5)]), KEY, vel=66)
    play(FID, bt(8), plain(A_TUNE), KEY, vel=76)
    play(FID, bt(16), plain(A2_TUNE), KEY, vel=78, ornament=True)
    play(REC, bt(23, 3.5), plain([(0, .5)]), hi, vel=64)
    play(REC, bt(24), plain(B_CALL), KEY, vel=72)          # recorder calls
    play(FID, bt(28), flat(B_ANSWER), KEY, vel=76, ornament=True)
    # B': fiddle takes the call, recorder harmonises above it.
    play(FID, bt(32), plain(B_CALL), KEY, vel=74, ornament=True)
    play(REC, bt(32), harmonise(plain(B_CALL), bt(32)), KEY, vel=60)
    play(FID, bt(36), flat(B2_END), KEY, vel=78, ornament=True)
    play(REC, bt(36), harmonise(flat(B2_END), bt(36)), KEY, vel=60)
    play(REC, bt(40), plain(INTER), hi, vel=64, legato=0.95)
    play(FID, bt(47, 3.5), plain([(0, .5)]), KEY, vel=66)
    play(FID, bt(48), flat(DEVELOP), KEY, vel=78, ornament=True)
    play(FID, bt(56), flat(BUILD), KEY, vel=80, ornament=True)
    t = bt(56)
    for item in DESCANT:
        if item[0] == "mixo":
            t = play(REC, t, [(item[1], item[2], MIXO)], hi, vel=58, legato=0.97)
        else:
            t = play(REC, t, plain([item]), hi, vel=58, legato=0.97)
    climax = GROWN_BAR + A2_TUNE[4:]
    play(FID, bt(64), plain(climax), KEY, vel=86, ornament=True)
    play(REC, bt(64), plain(GROWN_BAR), KEY + 12, vel=66)     # the grown motif in octaves
    play(REC, bt(65), harmonise(plain(A2_TUNE[4:]), bt(65)), KEY, vel=62)
    play(FID, bt(72), plain(OUTRO), KEY, vel=66, legato=0.95)
    return s


# --------------------------------------------------------------- colour
def build_colour():
    rnd = random.Random(77)
    s = Song(BPM, BPB)
    s.program(0, GM["harp"], vol=82, pan=86, reverb=72)
    s.program(1, GM["celesta"], vol=70, pan=36, reverb=80)
    s.program(2, GM["clarinet"], vol=72, pan=44, reverb=65)
    s.program(3, GM["oohs"], vol=58, pan=60, reverb=90)
    # Motif echoes on celesta, mostly where the tune holds or rests.
    echoes = [
        (3, 0, M.HEAD, 0), (7, 0, M.TAIL, 2), (11, 2.5, M.HEAD, 0), (15, 0.5, M.TAIL, 0),
        (23, 1.5, M.HEAD, 2), (27, 2, M.TAIL, 3), (31, 0, M.HEAD, 1), (39, 0, M.MOTIF, 0),
        (43, 2, M.TAIL, 0), (47, 0, M.HEAD, 1), (51, 2, M.TAIL, 0), (55, 2, M.HEAD, 4),
        (71, 1.5, M.TAIL, 2), (73, 1, M.HEAD, 2), (75, 1, M.ANSWER, 0), (79, 0, M.HEAD, 0),
    ]
    for bar, beat, ph, shift in echoes:
        t = bt(bar, beat)
        for pt, d in M.realise(ph, KEY + 12, SCALE, shift):
            if pt is not None:
                s.note(1, pt, sw(t), max(d, 1.0), 54 + rnd.randint(-6, 6))
            t += d
    # Harp: rising chord-tone sparkles, denser in the open sections.
    dens = [0.5, 0.35, 0.5, 0.45, 0.45, 0.7, 0.4, 0.5, 0.55, 0.6]
    for bar in range(BARS):
        sec, sbar = section_of(bar)
        if rnd.random() > dens[sec]:
            continue
        for cb, cd, name in chords_in(bar):
            if cd < BPB and rnd.random() < 0.5:
                continue
            vo = voicing(name, 67, 88, 5)
            start = rnd.choice([0, 0.5, 1, 2])
            if start >= cd:
                start = 0
            n = rnd.choice([3, 4, 4, 5])
            for k in range(n):
                s.note(0, vo[k % len(vo)], sw(bt(bar, cb + start + k * 0.5)), 2.0,
                       48 + rnd.randint(-6, 4) - k * 3)
    # Clarinet: a slow, voice-led inner line in the B sections and the build.
    prev = 62
    for sec in (3, 4, 7):
        for sbar in range(8):
            bar = sec * 8 + sbar
            for cb, cd, name in chords_in(bar):
                cands = [in_range(pc, 55) for pc in tones(name)] + [in_range(pc, 55) + 12 for pc in tones(name)]
                cands = [c for c in cands if 55 <= c <= 69 and c != prev] or [prev]
                pt = min(cands, key=lambda c: abs(c - prev))
                b0 = bt(bar, cb)
                s.note(2, pt, b0, cd - 0.1, 52)
                s.ramp(2, 11, 60, 110, b0, b0 + cd * 0.5, 5)
                s.ramp(2, 11, 110, 70, b0 + cd * 0.5, b0 + cd - 0.1, 5)
                prev = pt
    # Soft choir in the interlude and outro.
    for sec in (5, 9):
        for sbar in range(8):
            bar = sec * 8 + sbar
            for cb, cd, name in chords_in(bar):
                b0 = bt(bar, cb)
                s.chord(3, voicing(name, 57, 72, 3), b0, cd - 0.1, 48)
                s.ramp(3, 11, 40, 105, b0, b0 + cd * 0.5, 5)
                s.ramp(3, 11, 105, 50, b0 + cd * 0.5, b0 + cd - 0.1, 5)
    return s


# Stem balance (dB) applied after rendering, so each layer sits right in the mix.
MIX_DB = {"base": 2.0, "rhythm": 2.0, "melody": 0.0, "colour": 4.5, "tense": -2.0}

STEMS = {
    "base": build_base,
    "rhythm": build_rhythm,
    "melody": build_melody,
    "colour": build_colour,
    "tense": build_tense,
}


def era1_full_lufs():
    """Loudness (LUFS) of Era 1's full day mix, so Era 2 can sit at the same level."""
    d = out_path("assets", "audio", "music", "era1")
    try:
        full = sum(read_audio(os.path.join(d, s + ".ogg")) for s in ("base", "rhythm", "melody", "colour"))
    except Exception:  # Era 1 not rendered: fall back to peak normalising
        return None
    return lufs(full)


def main():
    outdir = out_path("assets", "audio", "music", "era2")
    middir = out_path("tools", "music", "midi", "era2")
    audio = {}
    for name, fn in STEMS.items():
        raw = render_song(fn(), tail_beats=10, keep_mid=os.path.join(middir, name + ".mid"))
        audio[name] = seam_loop(raw, N) * 10 ** (MIX_DB[name] / 20)
        print(f"  {name}: rendered {len(raw) / SR:.2f}s -> loop {N / SR:.3f}s")
    full = audio["base"] + audio["rhythm"] + audio["melody"] + audio["colour"]
    threat = audio["base"] + audio["tense"] + audio["colour"]
    everything = full + audio["tense"]
    ref = max(peak(full), peak(threat), peak(everything) / 1.12)  # all five at once stays < 0 dBFS
    g = 10 ** (-1.0 / 20) / ref              # the most gain the peaks allow
    target = era1_full_lufs()
    if target is not None:
        g = min(g, 10 ** ((target - lufs(full)) / 20))   # match Era 1's loudness
    for name, a in audio.items():
        write_ogg(os.path.join(outdir, name + ".ogg"), a * g)
    print(f"  mix peak {dbfs(peak(full * g)):.2f} dBFS, threat mix {dbfs(peak(threat * g)):.2f} dBFS, "
          f"full {lufs(full * g):.1f} LUFS (Era 1 {'n/a' if target is None else f'{target:.1f}'})")


if __name__ == "__main__":
    main()
