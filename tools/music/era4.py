"""Era 4 adaptive piece: "Valley Lights".

The valley lights up at night: a powerhouse, a foundry, rail, a refinery, a
launch tower on the old shrine, and a people who have decided to go and look
at the stars. Modern, hopeful, engineering-and-wonder: warm synth pads under
a string orchestra, a pulse-driven rhythm of piano ostinato and synth bass,
and the piano carrying the hand motif. Big, but warm and a little nostalgic,
building toward the launch.

G lydian, 4/4 at 96 bpm with a steady eighth-note pulse. G lydian (G A B C#
D E F#) is the brightest mode, a major scale with a raised fourth that never
quite sits down: the sound of wonder. Its signature chord, A major over G,
appears all through (A/G, II over the tonic). The scale holds the same notes
as D major, so the ending can step home to Era 1's D without a jolt.
88 bars (352 beats = exactly 220 s = 9,702,000 samples).

The motif is at its most complete here, and every earlier treatment of it
comes back as a memory inside the new sound:
  - Era 1: the lone pan flute calls the motif from far off in the intro and
    the night-sky interlude; kalimba echoes it in the colour stem; a soft
    frame-drum heartbeat holds the quiet sections.
  - Era 2: the recorder answers the piano in A'; the tune is re-barred in
    4/4 the way the village fiddle first sang it.
  - Era 3: the horn calls the motif round the chords and the piano answers
    down them (Era 3's develop); its library inversion returns for the
    night sky; its diminution becomes the engine room's motor figure; the
    church bells toll at section heads and peal at the climax.
  - Era 4's own: the motif grown to the octave and then on past it to the
    lydian C# (the hand opening wider than it ever has), and its answer
    (D C# B A G) falling home through that same raised fourth.

Form (8-bar sections):
  0 intro      night: pads and the powerhouse hum; the pan flute calls from
               far away, the piano answers
  1 A          the piano theme: the motif as a song, A/G lifting under it
  2 A'         the theme again, strings joining, the recorder answering
  3 B          the engine room: piano motor figures (the motif in
               diminution), a long violin line above
  4 B'         the long line an octave up, horn harmony beneath
  5 night sky  hushed: the motif inverted and slow on piano, celesta and
               music box, the pan flute far off
  6 develop    the horn calls the motif round the chords, the piano
               answers down them; the motors return
  7 build      a line rising step by step over a rising bass (E F# G A B)
  8 climax     the motif grown to the octave and on to C#: piano, horn,
               violins and pan flute together, bells pealing, choir
  9 return     the theme again, gentler
 10 outro      the answer falls home; the motif's question is left open on
               D over A/G -> loops to the intro

Stems (all the same length, all loop seamlessly at bar 88 -> bar 0):
  base    warm synth pad, polysynth pad, string orchestra, high violins,
          cello, contrabass, a low brass chorale in the build and climax
  rhythm  pulse: piano ostinato in eighths, soft synth bass, a light modern
          kit (kick, rim, closed hat, shaker); the quiet sections keep only
          a frame-drum heartbeat and a ticking hat
  melody  piano, violins, horn, recorder, pan flute
  colour  celesta and crystal-synth sparkle, glockenspiel and kalimba motif
          echoes, music box, tubular bells, soft choir
  tense   threat variant of rhythm (accidents, smog, a launch scrub):
          driving synth-bass sixteenths, toms and timpani, low brass stabs,
          tremolo strings, a ticking clock, a metallic warning swell.
          No melody.

Run:  python3 tools/music/era4.py
"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
from common import GM, SR, Song, dbfs, lufs, out_path, peak, read_audio, render_song, seam_loop, write_ogg  # noqa: E402
import motif as M  # noqa: E402

BPM = 96
BPB = 4
BARS = 88
BEATS = BARS * BPB
N = int(round(BEATS * 60 / BPM * SR))  # 9,702,000
assert N == 9_702_000
KEY = M.ERAS[4]["key"]      # G4
SCALE = M.ERAS[4]["scale"]  # lydian

# The modern sounds (General MIDI, 0-based) on top of common.GM.
G4 = dict(GM, ep=4, synth_bass=38, synth_bass2=39, synth_strings=50, polysynth=90,
          pad_bowed=92, pad_metal=93, pad_sweep=95, crystal=98, atmosphere=99,
          tubular=14)

# Chords: name -> (semitones above G, chord intervals, bass above G or None)
CH = {
    "G": (0, (0, 4, 7), None), "Gmaj7": (0, (0, 4, 7, 11), None),
    "A": (2, (0, 4, 7), None), "A/G": (2, (0, 4, 7), 0),
    "Bm": (4, (0, 3, 7), None), "Bm7": (4, (0, 3, 7, 10), None),
    "Cmaj7": (5, (0, 4, 7, 11), None),
    "D": (7, (0, 4, 7), None), "D/F#": (7, (0, 4, 7), 11), "Dsus": (7, (0, 5, 7), None),
    "Em": (9, (0, 3, 7), None), "Em7": (9, (0, 3, 7, 10), None),
    "F#m": (11, (0, 3, 7), None),
}
# One chord per bar; "G|D/F#" splits the bar in half.
HARM = [
    "Gmaj7 Gmaj7 A/G A/G Em7 Em7 Bm7 D",        # 0 intro
    "G A/G Bm Em Cmaj7 G|D/F# Em7 D",           # 1 A
    "G A/G Bm Em Cmaj7 A Dsus D",               # 2 A'
    "Em Bm Gmaj7 D Em Bm A A",                  # 3 B (engine room)
    "Em Bm Gmaj7 D/F# Em A Bm|A D",             # 4 B'
    "Gmaj7 A/G Gmaj7 A/G Em7 F#m Bm7 D",        # 5 night sky
    "Em Bm Cmaj7 G A D/F# Bm D",                # 6 develop
    "Em F#m G A Bm A Dsus D",                   # 7 build
    "G A/G Bm Em Cmaj7 A G|D/F# Em7|D",         # 8 climax
    "G A/G Bm Em Cmaj7 G|D/F# Em7 D",           # 9 return
    "Cmaj7 G A/G G Cmaj7 G A/G D",              # 10 outro -> loops to Gmaj7
]
BAR_CHORDS = [c for sec in HARM for c in sec.split()]
assert len(BAR_CHORDS) == BARS
# How full each section is (0 sparse .. 4 tutti).
DENS = [1, 2, 3, 3, 3, 1, 3, 3, 4, 2, 1]
QUIET = (0, 5, 10)


def bt(bar, beat=0.0):
    return bar * BPB + beat


def chords_in(bar):
    """[(beat_in_bar, beats, chord_name)] for a bar."""
    parts = BAR_CHORDS[bar % BARS].split("|")
    d = BPB / len(parts)
    return [(i * d, d, c) for i, c in enumerate(parts)]


def chord_at(t):
    bar = int(t // BPB)
    bib = t - bar * BPB
    return [c for cb, cd, c in chords_in(bar) if cb <= bib + 1e-6][-1]


def root_pc(name):
    return (KEY + CH[name][0]) % 12


def bass_pc(name):
    b = CH[name][2]
    return (KEY + (CH[name][0] if b is None else b)) % 12


def tones(name):
    off, iv, _ = CH[name]
    return [(KEY + off + i) % 12 for i in iv]


def is_minor(name):
    return CH[name][1][1] == 3


def scale_pcs(name):
    """The scale over a chord: G lydian, except over Cmaj7 (borrowed from G
    major, Era 2's key: a little nostalgia) the C# becomes C."""
    pcs = [(KEY + s) % 12 for s in M.SCALES[SCALE]]
    if name.startswith("C"):
        pcs = [0 if pc == 1 else pc for pc in pcs]
    return pcs


def in_range(pc, lo):
    """Lowest pitch of pitch class pc that is >= lo."""
    return lo + (pc - lo) % 12


def voicing(name, lo=55, hi=72, n=4):
    """Close-ish voicing of a chord inside [lo, hi] (sevenths keep their 7th)."""
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


def bars(*bs):
    """Flatten per-bar phrases, checking each bar fills 4 beats."""
    out = []
    for i, b in enumerate(bs):
        tot = sum(n[1] for n in b)
        assert abs(tot - BPB) < 1e-6, f"bar {i} has {tot} beats: {b}"
        out += b
    return out


# --------------------------------------------------------------- the tunes
# Notes are (degree, beats); degrees in G lydian from G4; None = rest.
# The theme (piano, bars 8-15, after a pickup at bar 7 beat 3).
A_TUNE = bars(
    [(0, 1.5), (1, .5), (2, 1), (4, 1)],                     # G      the motif
    [(5, 2), (4, .5), (3, .5), (1, 1)],                      # A/G    ...and the lydian C#
    [(2, 1.5), (1, .5), (2, 1), (4, 1)],                     # Bm
    [(6, 1.5), (5, .5), (4, 2)],                             # Em
    [(4, 1), (5, .5), (6, .5), (7, 1), (9, 1)],              # Cmaj7  the hand opens wider
    [(8, 1.5), (7, .5), (6, 1), (4, 1)],                     # G | D/F#
    [(5, 1.5), (4, .5), (2, 1), (1, 1)],                     # Em7
    [(1, 2), (None, 1), (-3, 1)],                            # D      (pickup)
)
A2_TUNE = bars(
    [(0, 1.5), (1, .5), (2, 1), (4, 1)],                     # G
    [(5, 1), (6, .5), (5, .5), (3, 1), (1, 1)],              # A/G
    [(2, 2), (4, 1), (6, 1)],                                # Bm
    [(7, 1.5), (6, .5), (5, 1), (4, 1)],                     # Em
    [(4, 1), (6, 1), (9, 2)],                                # Cmaj7
    [(8, 1.5), (10, .5), (9, 1), (8, 1)],                    # A
    [(7, 2), (4, 2)],                                        # Dsus
    [(6, 3), (None, 1)],                                     # D
)
# The engine room's long violin line (bars 24-31), then an octave-ish higher (32-39).
B_STR = bars(
    [(6, 2), (5, 1), (4, 1)],                                # Em
    [(4, 3), (2, 1)],                                        # Bm
    [(3, 2), (4, 1), (6, 1)],                                # Gmaj7  C# over G: wonder
    [(1, 2), (4, 2)],                                        # D
    [(7, 2), (6, 1), (5, 1)],                                # Em
    [(6, 3), (4, 1)],                                        # Bm
    [(5, 2), (3, 2)],                                        # A
    [(1, 4)],                                                # A
)
B2_STR = bars(
    [(6, 2), (5, 1), (4, 1)],                                # Em
    [(4, 3), (6, 1)],                                        # Bm
    [(7, 2), (10, 2)],                                       # Gmaj7
    [(8, 3), (6, 1)],                                        # D/F#
    [(9, 2), (7, 1), (5, 1)],                                # Em
    [(8, 1.5), (9, .5), (10, 2)],                            # A
    [(11, 2), (10, 2)],                                      # Bm | A
    [(8, 4)],                                                # D
)
# The night sky (piano, bars 40-47): Era 3's library inversion, the hand
# turned palm-up to the stars, then a slow rising answer through C#.
SKY = bars(
    [(4, 2), (1, 1.5), (0, .5)],                             # Gmaj7  D A G
    [(-1, 2), (-3, 2)],                                      # A/G    F# D
    [(2, 2), (1, 1), (3, 1)],                                # Gmaj7  B A C#
    [(5, 4)],                                                # A/G    E
    [(4, 2), (5, 1), (6, 1)],                                # Em7
    [(6, 2), (5, 1), (3, 1)],                                # F#m
    [(4, 3), (2, 1)],                                        # Bm7
    [(1, 3), (None, 1)],                                     # D
)
BUILD = bars(  # bars 56-63, over a bass rising E F# G A B
    [(2, 1.5), (4, .5), (5, 2)],                             # Em
    [(3, 1.5), (5, .5), (6, 2)],                             # F#m
    [(4, 1.5), (6, .5), (7, 2)],                             # G
    [(5, 1.5), (7, .5), (8, 2)],                             # A
    [(6, 1.5), (8, .5), (9, 2)],                             # Bm
    [(7, 1), (8, 1), (9, 1), (10, 1)],                       # A
    [(11, 3), (8, 1)],                                       # Dsus
    [(8, 2), (6, 1), (None, 1)],                             # D
)
# The climax (bars 64-71): the motif grown to the octave, then on up to C#.
CLIMAX = bars(
    [(0, 1), (1, .5), (2, .5), (4, 1), (7, 1)],              # G      M.GROWN in one bar
    [(8, 1.5), (9, .5), (10, 2)],                            # A/G    ...and on to C#
    [(11, 2), (9, 1), (8, 1)],                               # Bm
    [(9, 1.5), (8, .5), (7, 2)],                             # Em
    [(6, 1), (7, .5), (8, .5), (9, 2)],                      # Cmaj7
    [(10, 1.5), (9, .5), (8, 1), (10, 1)],                   # A
    [(11, 2), (8, 1), (6, 1)],                               # G | D/F#
    [(7, 1.5), (6, .5), (4, 2)],                             # Em7 | D
)
OUTRO = bars(
    [(None, 1), (6, 1.5), (4, .5), (2, 1)],                  # Cmaj7
    [(2, 3), (None, 1)],                                     # G
    [(4, 1), (3, .5), (2, .5), (1, 2)],                      # A/G   the answer, through C#...
    [(0, 3), (None, 1)],                                     # G     ...home
    [(None, 3), (-3, 1)],                                    # Cmaj7
    [(0, 1.5), (1, .5), (2, 1), (4, 1)],                     # G     the motif's question...
    [(4, 4)],                                                # A/G   ...left open on D
    [(None, 4)],                                             # D
)
INTRO_FLUTE = bars(
    [(None, 3), (-3, 1)],                                    # Gmaj7
    [(0, 1.5), (1, .5), (2, 1), (4, 1)],                     # Gmaj7  the first call, from far off
    [(4, 3), (None, 1)],                                     # A/G
)
INTRO_PIANO = bars(
    [(None, 2), (5, 1), (4, 1)],                             # Em7
    [(2, 3), (1, 1)],                                        # Bm7
    [(1, 2), (None, 1), (-3, 1)],                            # D     (pickup into A)
)


def realise(t, notes, key, scale=SCALE, shift=0):
    """[(t, beats, pitch)] for a phrase starting at beat t (rests skipped)."""
    out = []
    for n in notes:
        d, b = n[0], n[1]
        if d is not None:
            out.append((t, b, M.pitch(d + shift, key, scale)))
        t += b
    return out


REG = []  # every melody note (t0, t1, pitch, ch), for the counter-lines to listen to


def sounding(t, exclude_ch=None):
    return [p for t0, t1, p, ch in REG if t0 <= t + 1e-6 < t1 and ch != exclude_ch]


def harm_below(line):
    """A second voice under a realised line: on strong notes the nearest chord
    tone 3-9 semitones below, on quick weak notes the diatonic third below."""
    out = []
    for t, b, p in line:
        name = chord_at(t)
        strong = b >= 1 or abs(t - round(t)) < 1e-6
        cands = [q for q in range(p - 9, p - 2) if q % 12 in tones(name)]
        if strong and cands:
            q = max(cands)
        else:
            below = [q for q in range(p - 4, p - 2) if q % 12 in scale_pcs(name)]
            q = below[-1] if below else (max(cands) if cands else p - 3)
        out.append((t, b, q))
    return out


DISSONANT = {1, 2, 6, 10, 11}


def counter(rnd, t0, t1, lo, hi, ch, style="quarters"):
    """A free counter-line of chord tones between beats t0 and t1 in [lo, hi],
    stepping smoothly and keeping consonant with the melody notes it meets."""
    out = []
    prev = (lo + hi) // 2
    t = t0
    while t < t1 - 1e-6:
        bar = int(t // BPB)
        bib = t - bar * BPB
        if style == "halves":
            dur = 2.0 if abs(bib % 2) < 1e-6 else 1.0
        elif style == "wholes":
            dur = BPB - bib
        else:
            dur = rnd.choice([1, 1, 1, 2]) if abs(bib % 2) < 1e-6 else 1.0
            if bib >= 2 and abs(bib - 2) < 1e-6 and rnd.random() < 0.3:
                dur = 1.5
        dur = min(dur, t1 - t)
        for cb, cd, _ in chords_in(bar):     # never hold across a chord change
            if bib < cb - 1e-6 < bib + dur:
                dur = cb - bib
        name = chord_at(t)
        best, cost = prev, 1e9
        for p in range(lo, hi + 1):
            if p % 12 not in tones(name):
                continue
            c = abs(p - prev) * (1.0 if abs(p - prev) <= 4 else 2.0)
            if p == prev:
                c += 2.5
            for k in (0.0, 0.5 * dur):
                for q in sounding(t + k, ch):
                    iv = abs(p - q) % 12
                    if iv in DISSONANT:
                        c += 25
                    if iv == 0:
                        c += 6
            c += rnd.uniform(0, 1.5)
            if c < cost:
                best, cost = p, c
        out.append((t, dur, best))
        prev = best
        t += dur
    return out


def motor(bar, lo):
    """The engine-room figure for one bar: the motif in diminution on the
    chord root (fifth below, root, step, third, fifth), then its answer
    falling back down, in eighths and sixteenths."""
    out = []
    for cb, cd, name in chords_in(bar):
        r = in_range(root_pc(name), lo)
        third = 3 if is_minor(name) else (5 if name == "Dsus" else 4)
        fig = [(-5, .5), (0, .5), (2, .25), (third, .25), (7, .5)]
        if cd >= BPB:
            fig += [(12, .5), (7, .25), (third, .25), (2, .5), (0, .5)]
        t = bt(bar, cb)
        for semi, d in fig:
            out.append((t, d, r + semi))
            t += d
    return out


# --------------------------------------------------------------- melody
def build_melody():
    rnd = random.Random(404)
    REG.clear()
    s = Song(BPM, BPB)
    PNO, VLN, HORN, REC, PANF, PNO2 = 0, 1, 2, 3, 4, 5
    s.program(PNO, G4["piano"], vol=104, pan=60, reverb=66)
    s.program(VLN, G4["strings"], vol=84, pan=74, reverb=72)
    s.program(HORN, G4["horn"], vol=92, pan=44, reverb=66)
    s.program(REC, G4["recorder"], vol=74, pan=84, reverb=72)
    s.program(PANF, G4["pan_flute"], vol=82, pan=36, reverb=88, chorus=10)
    s.program(PNO2, G4["piano"], vol=86, pan=52, reverb=66)

    def play(ch, line, vel=78, legato=0.92, swell=True):
        """Play a realised line [(t, beats, pitch)]."""
        for t, b, p in line:
            v = vel + rnd.randint(-4, 4) + (4 if b >= 2 else 0)
            v += 4 if abs(t % 2) < 1e-6 else (1 if abs(t % 1) < 1e-6 else -3)
            st = t + rnd.uniform(-0.008, 0.008)
            if ch in (PNO, PNO2):     # piano: let notes ring, the pedal does the legato
                s.note(ch, p, st, b * 0.98, v)
            else:
                s.note(ch, p, st, b * (legato if b >= 0.5 else 0.82), v)
            REG.append((t, t + b, p, ch))
            if ch in (PNO, PNO2):
                continue
            if b >= 1.5 and swell:
                s.ramp(ch, 11, 86, 124, st, st + b * 0.5, 5)
                s.ramp(ch, 11, 124, 94, st + b * 0.55, st + b * legato, 5)
            else:
                s.cc(ch, 11, 112, st)

    def pedal(ch, b0, b1):
        """Sustain pedal, changed with every chord."""
        bar0, bar1 = int(b0 // BPB), int((b1 - 1e-6) // BPB)
        for bar in range(bar0, bar1 + 1):
            for cb, cd, _ in chords_in(bar):
                t = bt(bar, cb)
                if b0 - 1e-6 <= t < b1:
                    s.cc(ch, 64, 0, t - 0.02)
                    s.cc(ch, 64, 127, t + 0.04)
        s.cc(ch, 64, 0, b1 - 0.05)

    # 0 intro: the pan flute calls from far away; the piano answers.
    play(PANF, realise(bt(1), INTRO_FLUTE, KEY + 12), vel=58, legato=0.94)
    play(PNO, realise(bt(5), INTRO_PIANO, KEY + 12), vel=58)
    # 1 A: the piano theme, a soft lower voice in its second half.
    a = realise(bt(8), A_TUNE, KEY + 12)
    play(PNO, a, vel=74)
    play(PNO2, harm_below([n for n in a if bt(12) <= n[0] < bt(15)]), vel=48)
    # 2 A': the theme again; violins double it an octave down from bar 20;
    # the recorder (Era 2's) answers in the gaps.
    a2 = realise(bt(16), A2_TUNE, KEY + 12)
    play(PNO, a2, vel=76)
    play(VLN, [(t, b, p - 12) for t, b, p in a2 if t >= bt(20)], vel=62, legato=0.97)
    play(REC, counter(rnd, bt(16), bt(20), 74, 86, REC, "halves"), vel=52, legato=0.95)
    # 3 B: the engine room. Piano motor figures; a long violin line above.
    play(VLN, realise(bt(24), B_STR, KEY + 12), vel=70, legato=0.98)
    for bar in range(24, 32):
        play(PNO2, motor(bar, 55), vel=54)
    # 4 B': the long line higher, horn harmony beneath; the motors carry on.
    b2 = realise(bt(32), B2_STR, KEY)
    b2 = [(t, b, p + 12 if p < 76 else p) for t, b, p in b2]
    play(VLN, b2, vel=72, legato=0.98)
    play(HORN, [(t, b, p - 12) for t, b, p in harm_below(b2)], vel=60, legato=0.96)
    for bar in range(32, 40):
        play(PNO2, motor(bar, 55), vel=56)
    play(PNO, realise(bt(39, 3), [(-3, 1)], KEY + 12), vel=50)
    # 5 night sky: the inversion, slow, piano alone; the pan flute far off.
    play(PNO, realise(bt(40), SKY, KEY + 12), vel=58)
    play(PANF, realise(bt(46, 2), [(-3, 1), (0, 1), (1, 2), (2, 4)], KEY + 12), vel=50, legato=0.95)
    # 6 develop: Era 3's horn calls round the chords; the piano answers down them.
    for k, bar in enumerate(range(48, 56)):
        name = BAR_CHORDS[bar]
        third = 3 if is_minor(name) else 4
        if k % 2 == 0:
            r = in_range(root_pc(name), 55)
            iv = [(-5, .5), (0, 1), (2, .5), (third, .5), (7, 1.5)]
            ch, vel = HORN, 74
        else:
            r = in_range(root_pc(name), 72)
            iv = [(7, .5), (third, .5), (2, .5), (0, 1), (-5, 1.5)]
            ch, vel = PNO, 70
        t = bt(bar)
        line = []
        for semi, b in iv:
            line.append((t, b, r + semi))
            t += b
        play(ch, line, vel=vel, legato=0.9)
    play(VLN, counter(rnd, bt(48), bt(56), 67, 79, VLN, "halves"), vel=54, legato=0.97)
    for bar in range(48, 56, 2):
        play(PNO2, [n for n in motor(bar + 1, 50) if n[0] < bt(bar + 1, 2)], vel=46)
    # 7 build: violins rise, the piano an octave above from the fourth bar.
    bl = realise(bt(56), BUILD, KEY + 12)
    play(VLN, bl, vel=70, legato=0.97)
    play(PNO, [(t, b, p + 12) for t, b, p in bl if t >= bt(59)], vel=62)
    play(HORN, counter(rnd, bt(56), bt(63), 55, 67, HORN, "halves"), vel=58, legato=0.97)
    play(HORN, realise(bt(63, 3), [(-3, 1)], KEY), vel=72)
    play(PNO, realise(bt(63, 3), [(-3, 1)], KEY + 12), vel=66)
    # 8 climax: everyone who ever carried the motif, together.
    cl = realise(bt(64), CLIMAX, KEY + 12)
    play(PNO, cl, vel=86)
    play(PNO2, [(t, b, p - 12) for t, b, p in cl], vel=60)
    play(HORN, [(t, b, p - 12) for t, b, p in cl], vel=80)
    play(VLN, harm_below(cl), vel=74, legato=0.97)
    play(PANF, [(t, b, p) for t, b, p in cl if t >= bt(68)], vel=60, legato=0.94)
    # 9 return: the theme again, gentler; cello-register violins beneath.
    play(PNO, realise(bt(71, 3), [(-3, 1)], KEY + 12), vel=58)
    rt = realise(bt(72), A_TUNE, KEY + 12)
    play(PNO, rt, vel=66)
    play(VLN, [(t, b, p - 12) for t, b, p in harm_below(rt)], vel=50, legato=0.96)
    # 10 outro: the answer home, then the question left open.
    play(PNO, realise(bt(80), OUTRO, KEY + 12), vel=58)
    pedal(PNO, 0, BEATS)
    return s


# --------------------------------------------------------------- base
def build_base():
    rnd = random.Random(41)
    s = Song(BPM, BPB)
    PAD, POLY, STR, HIGH, CEL, CB, BRASS = 0, 1, 2, 3, 4, 5, 6
    s.program(PAD, G4["pad_warm"], vol=74, pan=60, reverb=82, chorus=40)
    s.program(POLY, G4["polysynth"], vol=50, pan=70, reverb=80, chorus=60)
    s.program(STR, G4["strings"], vol=70, pan=56, reverb=74, chorus=10)
    s.program(HIGH, G4["slow_strings"], vol=58, pan=84, reverb=82)
    s.program(CEL, G4["cello"], vol=76, pan=74, reverb=58)
    s.program(CB, G4["contrabass"], vol=66, pan=64, reverb=48)
    s.program(BRASS, G4["horn"], vol=54, pan=40, reverb=72)
    for bar in range(BARS):
        sec, sbar = section_of(bar)
        b = bt(bar)
        quiet = sec in QUIET
        for cb, cd, name in chords_in(bar):
            t0 = b + cb
            bp = in_range(bass_pc(name), 36)
            # The warm pad: low, wide, always there; restruck each chord.
            pv = sorted({bp + 12} | set(voicing(name, 55, 70, 3)))
            s.chord(PAD, pv, t0, cd - 0.02, 54 if quiet else 60)
            # The polysynth adds air in the brighter sections.
            if not quiet or sec == 5:
                s.chord(POLY, voicing(name, 62, 79, 4), t0, cd - 0.05, 40 if sec != 8 else 48)
            # Strings: a wide voicing with a swell through each chord.
            if sec != 0 or sbar >= 4:
                vel = 40 if quiet else (56 if sec == 8 else 48)
                s.chord(STR, voicing(name, 52, 74, 4 if quiet else 5), t0, cd - 0.05, vel)
                s.ramp(STR, 11, 72, 118, t0, t0 + cd * 0.55, 6)
                s.ramp(STR, 11, 118, 88, t0 + cd * 0.6, t0 + cd - 0.05, 6)
            if DENS[sec] >= 3:
                s.chord(HIGH, voicing(name, 76, 88, 2), t0, cd - 0.05, 36 + (6 if sec == 8 else 0))
            # Cello on the bass note; moving to the fifth in the fuller sections.
            if quiet or cd < BPB:
                s.note(CEL, bp, t0, cd - 0.1, 54)
            else:
                fifth = in_range(root_pc(name), 36) + 7
                fifth = fifth if fifth <= 55 else fifth - 12
                s.note(CEL, bp, t0, 2.9, 58)
                s.note(CEL, fifth if DENS[sec] >= 3 else bp, t0 + 3, 0.95, 46)
            if not quiet or sec == 5:
                s.note(CB, bp - 12 if bp - 12 >= 28 else bp, t0, cd - 0.1, 48 if sec != 8 else 58)
            # Low brass chorale in the build and climax.
            if sec in (7, 8):
                s.chord(BRASS, voicing(name, 47, 62, 3), t0, cd - 0.08, (46 if sec == 7 else 54) + rnd.randint(-3, 3))
                s.ramp(BRASS, 11, 70, 118, t0, t0 + cd * 0.5, 4)
                s.ramp(BRASS, 11, 118, 86, t0 + cd * 0.5, t0 + cd - 0.08, 4)
        # The powerhouse hum: a low G drone under the intro and night sky.
        if sec in (0, 5) and sbar == 0:
            s.note(PAD, 31, b, 8 * BPB - 0.1, 40)
    return s


# --------------------------------------------------------------- rhythm
def build_rhythm():
    rnd = random.Random(42)
    s = Song(BPM, BPB)
    s.program(9, 0, vol=84, reverb=36)
    PNO, SB, EP = 0, 1, 2
    s.program(PNO, G4["piano"], vol=70, pan=40, reverb=58)
    s.program(SB, G4["synth_bass2"], vol=70, pan=64, reverb=30)
    s.program(EP, G4["ep"], vol=62, pan=82, reverb=60, chorus=40)
    KICK, RIM, HAT, PHAT, SHAKER, FRAME, CRASH, RIDE, TAMB, SNARE = 36, 37, 42, 44, 70, 41, 49, 51, 54, 38

    def hit(n, b, v, d=0.2):
        s.note(9, n, b + rnd.uniform(-0.008, 0.008), d, v + rnd.randint(-4, 4))

    for bar in range(BARS):
        sec, sbar = section_of(bar)
        d = DENS[sec]
        b = bt(bar)
        fill = sbar == 7 and d >= 2
        # The kit.
        if d == 1:
            # Era 1's heartbeat on the frame drum, and the clock of the observatory.
            hit(FRAME, b, 46)
            hit(FRAME, b + 0.75, 26)
            for k in range(4):
                hit(PHAT, b + k + 0.5, 16)
        if d >= 2:
            hit(KICK, b, 54)
            hit(KICK, b + 2.5, 34)
            if d >= 3:
                hit(KICK, b + 2, 46)
            hit(RIM, b + 1, 30)
            hit(RIM, b + 3, 34 + (6 if d >= 3 else 0))
            for k in range(8):
                hit(HAT, b + k * 0.5, (30 if k % 2 == 0 else 20) + (4 if d >= 3 else 0), 0.1)
        if d >= 3:
            for k in range(16):
                if k % 2:
                    hit(SHAKER, b + k * 0.25, 18 + (6 if k % 4 == 1 else 0), 0.1)
        if d == 4:
            hit(TAMB, b + 1, 28)
            hit(TAMB, b + 3, 30)
            if sbar == 0:
                hit(CRASH, b, 48, 2.0)
        if fill:
            for k in range(8):   # a soft snare roll rising into the next section
                s.note(9, SNARE, b + 2 + k * 0.25 + rnd.uniform(-0.006, 0.006), 0.15, 14 + k * 5)
        if bar == 63:
            for k in range(16):
                s.note(9, RIDE, b + k * 0.25, 0.2, 16 + k * 3)
        # The piano ostinato: broken chords in steady eighths (quarters when quiet).
        for cb, cd, name in chords_in(bar):
            vo = voicing(name, 62, 76, 4)
            low = in_range(root_pc(name), 50)
            pat = [low, vo[0], vo[2], vo[1], vo[3] if len(vo) > 3 else vo[2], vo[1], vo[2], vo[0]]
            step = 1.0 if d == 1 else 0.5
            for k in range(int(cd / step)):
                pos = b + cb + k * step
                if d == 1 and sec != 5 and k % 2:
                    continue
                v = (40 if k % 4 == 0 else 32) + (4 if d >= 3 else 0) + rnd.randint(-3, 3)
                s.note(PNO, pat[k % len(pat)], pos + rnd.uniform(-0.005, 0.005), step * 1.5, v)
            # Synth bass: soft pulsing eighths on the bass note.
            bp = in_range(bass_pc(name), 31)
            if d >= 2:
                for k in range(int(cd * 2)):
                    if d == 2 and k % 2:
                        continue
                    octave = 12 if (k % 4 == 3 and d >= 3) else 0
                    s.note(SB, bp + octave, b + cb + k * 0.5, 0.38, (62 if k % 2 == 0 else 48) + rnd.randint(-3, 3))
            # Electric piano: off-beat chord pulses in the fullest sections.
            if d >= 3:
                for k in range(int(cd)):
                    s.chord(EP, voicing(name, 60, 74, 3), b + cb + k + 0.5, 0.35, 36 + rnd.randint(-3, 3))
        for cb, cd, name in chords_in(bar):   # half pedal, changed with each chord
            s.cc(PNO, 64, 0, b + cb - 0.02)
            s.cc(PNO, 64, 100, b + cb + 0.03)
    return s


# --------------------------------------------------------------- colour
def build_colour():
    rnd = random.Random(48)
    s = Song(BPM, BPB)
    CELESTA, GLOCK, KAL, BOX, BELLS, CHOIR, CRYS = 0, 1, 2, 3, 4, 5, 6
    s.program(CELESTA, G4["celesta"], vol=72, pan=30, reverb=82)
    s.program(GLOCK, G4["glock"], vol=58, pan=80, reverb=82)
    s.program(KAL, G4["kalimba"], vol=74, pan=88, reverb=78)
    s.program(BOX, G4["music_box"], vol=70, pan=70, reverb=86)
    s.program(BELLS, G4["tubular"], vol=62, pan=60, reverb=92)
    s.program(CHOIR, G4["oohs"], vol=62, pan=50, reverb=92)
    s.program(CRYS, G4["crystal"], vol=50, pan=40, reverb=80, chorus=40)
    # Era 1's kalimba and Era 3's glockenspiel echo the motif where the tune rests.
    echoes = [(3, 2, "head", KAL), (7, 2, "tail", KAL), (11, 2, "head", GLOCK), (15, 0, "tail", GLOCK),
              (23, 2, "head", GLOCK), (31, 0, "motif", KAL), (41, 2, "head", KAL), (43, 0, "tail", KAL),
              (47, 2, "head", GLOCK), (55, 2, "tail", GLOCK), (71, 2, "head", GLOCK), (79, 0, "tail", KAL),
              (81, 0, "head", KAL), (83, 2, "tail", KAL), (87, 0, "motif", KAL)]
    for bar, beat, kind, ch in echoes:
        name = chord_at(bt(bar, beat))
        r = in_range(root_pc(name), 74)
        third = 3 if is_minor(name) else (5 if name == "Dsus" else 4)
        shape = {"head": [(-5, .5), (0, .5), (2, 1)],
                 "tail": [(2, .5), (third, .5), (7, 1)],
                 "motif": [(-5, .5), (0, .75), (2, .25), (third, .5), (7, 1.5)]}[kind]
        t = bt(bar, beat)
        for semi, d in shape:
            s.note(ch, r + semi, t, max(d, 1.0), 50 + rnd.randint(-5, 5))
            t += d
    # Celesta and music box: the night sky's stars (quiet sections).
    for bar in range(BARS):
        sec, sbar = section_of(bar)
        if sec not in QUIET:
            continue
        cb, cd, name = chords_in(bar)[0]
        vo = voicing(name, 79, 96, 5)
        if rnd.random() < (0.75 if sec == 5 else 0.45):
            start = rnd.choice([0.5, 1.0, 1.5, 2.0])
            ch = BOX if sec == 5 and sbar % 2 else CELESTA
            for k in range(rnd.choice([2, 3, 4])):
                s.note(ch, vo[(k * 2) % len(vo)], bt(bar, start + k * 0.5), 1.5, 40 + rnd.randint(-5, 4) - k * 2)
    # Crystal synth: sixteenth arpeggios in the engine room, the build and climax.
    for bar in range(BARS):
        sec, sbar = section_of(bar)
        if sec not in (3, 4, 7, 8):
            continue
        for cb, cd, name in chords_in(bar):
            vo = voicing(name, 74, 91, 4)
            fig = vo + vo[-2:0:-1]
            for k in range(int(cd * 4)):
                if sec in (3, 4) and (k // 4) % 2:
                    continue   # gaps, so the engine breathes
                v = (30 if k % 4 == 0 else 22) + (6 if sec == 8 else 0) + rnd.randint(-3, 3)
                s.note(CRYS, fig[k % len(fig)], bt(bar, cb) + k * 0.25, 0.3, v)
    # Era 3's bells: a toll at section heads, then a peal at the climax.
    for bar in (8, 32, 72):
        s.note(BELLS, 55, bt(bar), 4.0, 44)
    peal = [79, 76, 74, 71, 69, 67]          # G E D B A G: G major pentatonic, safe over every chord
    t = bt(64)
    row = list(peal)
    for i in range(6):
        for k, p in enumerate(row):
            s.note(BELLS, p, t + rnd.uniform(-0.02, 0.02), 2.5, (40 if i < 2 else 46) + (6 if k == 0 else 0))
            t += 0.5
        t += 0.5
        for k in range(i % 2, len(row) - 1, 2):
            row[k], row[k + 1] = row[k + 1], row[k]
    # Soft choir: the climax, the night sky and the outro.
    for sec, vel in ((5, 38), (8, 52), (10, 40)):
        for sbar in range(8):
            bar = sec * 8 + sbar
            for cb, cd, name in chords_in(bar):
                b0 = bt(bar, cb)
                s.chord(CHOIR, voicing(name, 57, 72, 3), b0, cd - 0.1, vel)
                s.ramp(CHOIR, 11, 40, 108, b0, b0 + cd * 0.5, 5)
                s.ramp(CHOIR, 11, 108, 54, b0 + cd * 0.5, b0 + cd - 0.1, 5)
    return s


# --------------------------------------------------------------- tense
def build_tense():
    rnd = random.Random(49)
    s = Song(BPM, BPB)
    s.program(9, 0, vol=92, reverb=40)
    TIMP, TBN, SB, TREM, METAL, CB = 0, 1, 2, 3, 4, 5
    s.program(TIMP, G4["timpani"], vol=90, reverb=55)
    s.program(TBN, G4["trombone"], vol=78, pan=50, reverb=50)
    s.program(SB, G4["synth_bass"], vol=70, pan=64, reverb=30)
    s.program(TREM, G4["tremolo"], vol=66, pan=40, reverb=60)
    s.program(METAL, G4["pad_metal"], vol=58, pan=80, reverb=80)
    s.program(CB, G4["contrabass"], vol=72, reverb=40)
    KICK, FLOOR, LOW_TOM, WOOD_H, WOOD_L, HAT = 36, 41, 45, 76, 77, 42

    def hit(ch, n, b, v, d=0.2):
        s.note(ch, n, b + rnd.uniform(-0.005, 0.005), d, v + rnd.randint(-4, 4))

    for bar in range(BARS):
        sec, sbar = section_of(bar)
        b = bt(bar)
        # Kit: a driving 3+3+2 on the toms, the clock ticking in sixteenths.
        for pos in (0, 1.5, 3):
            hit(9, FLOOR if pos == 0 else LOW_TOM, b + pos, 66 if pos == 0 else 50)
        hit(9, KICK, b, 62)
        hit(9, KICK, b + 1.5, 46)
        hit(9, KICK, b + 3, 50)
        for k in range(16):
            hit(9, WOOD_H if k % 4 == 0 else HAT, b + k * 0.25, 34 if k % 4 == 0 else 16, 0.1)
        for cb, cd, name in chords_in(bar):
            r = in_range(root_pc(name), 31)
            # Synth bass sixteenths: root and octave, the engines straining.
            for k in range(int(cd * 4)):
                q = r + (12 if k % 8 in (3, 6) else 0)
                hit(SB, q, b + cb + k * 0.25, 58 if k % 4 == 0 else 40, 0.18)
            hit(CB, r + 12 if r + 12 <= 43 else r, b + cb, 60, min(cd, 2) - 0.1)
            # Trombone stabs on the 3+3+2.
            for pos, v in ((0, 66), (1.5, 54), (3, 58)):
                if pos < cd:
                    s.chord(TBN, [r + 12, r + 19], b + cb + pos, 0.35, v + rnd.randint(-4, 4))
            # Tremolo strings swelling on root, fifth and octave.
            s.chord(TREM, [r + 24, r + 31, r + 36], b + cb, cd - 0.05, 48)
            s.ramp(TREM, 11, 50, 118, b + cb, b + cb + cd * 0.85, 6)
            if cb == 0 and sbar % 2 == 0:
                hit(TIMP, r + 12 if r < 36 else r, b, 78, 2.0)
        # Timpani roll every four bars.
        if sbar % 4 == 3:
            r = in_range(root_pc(chords_in(bar)[-1][2]), 36)
            r = r - 12 if r > 45 else r
            for k in range(12):
                hit(TIMP, r, b + 1 + k * 0.25, 30 + k * 5, 0.25)
        # The warning: a metallic swell on root and fifth every two bars.
        if sbar % 2 == 0:
            r = in_range(root_pc(chords_in(bar)[0][2]), 62)
            s.chord(METAL, [r, r + 7], b, 7.8, 54)
            s.ramp(METAL, 11, 30, 110, b, b + 4, 6)
            s.ramp(METAL, 11, 110, 40, b + 4, b + 7.8, 6)
        if sbar == 7:
            for k in range(8):
                hit(9, WOOD_L, b + 2 + k * 0.25, 30 + k * 4, 0.1)
    return s


# Stem balance (dB) applied after rendering, so each layer sits right in the mix
# (tuned so every mix the director plays is within 1 LU of Era 1's).
MIX_DB = {"base": -2.2, "rhythm": -0.2, "melody": 2.8, "colour": 8.5, "tense": -1.3}

STEMS = {
    "base": build_base,
    "rhythm": build_rhythm,
    "melody": build_melody,
    "colour": build_colour,
    "tense": build_tense,
}


def era1_full_lufs():
    """Loudness (LUFS) of Era 1's full day mix, so Era 4 can sit at the same level."""
    d = out_path("assets", "audio", "music", "era1")
    try:
        full = sum(read_audio(os.path.join(d, s + ".ogg")) for s in ("base", "rhythm", "melody", "colour"))
    except Exception:  # Era 1 not rendered: fall back to peak normalising
        return None
    return lufs(full)


def render_stems():
    middir = out_path("tools", "music", "midi", "era4")
    raw = {}
    for name, fn in STEMS.items():
        r = render_song(fn(), tail_beats=10, keep_mid=os.path.join(middir, name + ".mid"))
        raw[name] = seam_loop(r, N)
        print(f"  {name}: rendered {len(r) / SR:.2f}s -> loop {N / SR:.3f}s")
    return raw


def mixdown(raw, mix_db=None):
    mix_db = mix_db or MIX_DB
    audio = {name: a * 10 ** (mix_db[name] / 20) for name, a in raw.items()}
    full = audio["base"] + audio["rhythm"] + audio["melody"] + audio["colour"]
    threat = audio["base"] + audio["tense"] + audio["colour"]
    everything = full + audio["tense"]
    ref = max(peak(full), peak(threat), peak(everything) / 1.12)  # all five at once stays < 0 dBFS
    g = 10 ** (-1.0 / 20) / ref              # the most gain the peaks allow
    target = era1_full_lufs()
    if target is not None:
        g = min(g, 10 ** ((target - lufs(full)) / 20))   # match Era 1's loudness
    return {name: a * g for name, a in audio.items()}, target


def main():
    outdir = out_path("assets", "audio", "music", "era4")
    audio, target = mixdown(render_stems())
    for name, a in audio.items():
        write_ogg(os.path.join(outdir, name + ".ogg"), a)
    full = audio["base"] + audio["rhythm"] + audio["melody"] + audio["colour"]
    threat = audio["base"] + audio["tense"] + audio["colour"]
    print(f"  mix peak {dbfs(peak(full)):.2f} dBFS, threat mix {dbfs(peak(threat)):.2f} dBFS, "
          f"all five {dbfs(peak(full + audio['tense'])):.2f} dBFS, "
          f"full {lufs(full):.1f} LUFS (Era 1 {'n/a' if target is None else f'{target:.1f}'})")


if __name__ == "__main__":
    main()
