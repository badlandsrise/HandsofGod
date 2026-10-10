"""Era 3 adaptive piece: "Market Bells".

A busy, prospering town of crafts, trade, a library and early science. Where
Era 2 was a village band, this is a small civic orchestra: French horn and
trumpet, oboe, flute, clarinet and bassoon, harpsichord, piano, full strings,
tuba, and church bells ringing changes over the rooftops.

F major, 4/4 at 108 bpm with straight eighths: a light march with a warm
heart. Era 1 is a 3/4 lilt in D dorian and Era 2 a swung common time in G, so
the brisker, square pulse and the new key are heard at once. The harmony is
more worldly too: secondary dominants (A7, D7, G7), a market section that
moves to C, and a quiet library interlude in D minor. 96 bars (384 beats =
exactly 213.333 s = 9,408,000 samples).

The hand motif grows in a new way here: it is worked like a learned tune.
It becomes a fanfare on horn, a march tune, quick market chatter (diminution),
a slow inversion in the library (the hand turned palm-down, reading), and the
subject of a little fugato for the workshop of early science, with tonal
answers in C. The develop section sequences it round the circle of fifths;
the climax grows it to the octave on trumpet, with the bells pealing.

Form (8-bar sections):
  0 intro      bells ring rounds; the horn calls the motif from afar
  1 A          the town tune on horn: the motif as a march melody
  2 A'         oboe takes the tune, flute joins, horn counter-line
  3 B          the market (in C): clarinet and bassoon chatter the motif
               in quick notes, then an oboe line over them
  4 B'         flute and clarinet in thirds, back towards F via A7 and C7
  5 library    D minor, hushed: the motif inverted and slow on clarinet,
               piano turning pages
  6 fugato     the workshop: the motif as a fugue subject, entering on
               bassoon, clarinet (answer in C), oboe, flute; a clockwork
               woodblock ticking
  7 develop    the motif sequenced round D7-Gm-C7-F-A7-Dm, horn calling,
               oboe answering
  8 build      a rising woodwind line against a horn counter-line
  9 climax     the motif grown to the octave on trumpet, horns in thirds,
               bells pealing, choir
 10 return     the tune again, gentler, on clarinet with a horn second
 11 outro      fragments, then the motif's question on C -> loops to F

Stems (all the same length, all loop seamlessly at bar 96 -> bar 0):
  base    full strings, cello, contrabass, a soft French-horn pad, low brass
          chorale in the build and climax
  rhythm  light march kit (snare, bass drum, triangle, woodblock), tuba
          oom-pah, pizzicato off-beats, bustling harpsichord; in the library
          just a ticking clock and a soft pizzicato walk
  melody  horn, trumpet, oboe, flute, clarinet, bassoon
  colour  church bells (rounds and plain hunt), glockenspiel motif echoes,
          piano (pages turning in the library, sparkle elsewhere), piccolo
          birdsong, soft choir
  tense   threat variant of rhythm (town fire, sickness, storms): a fire
          bell, driving snare, timpani, trombone stabs, cello ostinato,
          tremolo strings. No melody.

Run:  python3 tools/music/era3.py
"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
from common import GM, SR, Song, dbfs, lufs, out_path, peak, read_audio, render_song, seam_loop, write_ogg  # noqa: E402
import motif as M  # noqa: E402

BPM = 108
BPB = 4
BARS = 96
BEATS = BARS * BPB
N = int(round(BEATS * 60 / BPM * SR))  # 9,408,000
assert N == 9_408_000
KEY = M.ERAS[3]["key"]      # F4
SCALE = M.ERAS[3]["scale"]  # major

# Chords: name -> (semitones above F, chord intervals)
CH = {
    "F": (0, (0, 4, 7)), "Bb": (5, (0, 4, 7)), "C": (7, (0, 4, 7)), "C7": (7, (0, 4, 7, 10)),
    "Dm": (9, (0, 3, 7)), "Gm": (2, (0, 3, 7)), "Am": (4, (0, 3, 7)), "Em": (11, (0, 3, 7)),
    "G7": (2, (0, 4, 7, 10)), "A7": (4, (0, 4, 7, 10)), "D7": (9, (0, 4, 7, 10)),
}
# One chord per bar; "F|A7" splits the bar in half.
HARM = [
    "F F Bb F Gm Bb C C",                     # 0 intro
    "F Bb F C Dm Gm C7 F",                    # 1 A
    "F Bb F|A7 Dm Bb F|D7 Gm|C7 F",           # 2 A'
    "C Am Dm G7 C Am D7 G7",                  # 3 B (market, in C)
    "C Am F G7 Em|A7 Dm G7 C7",               # 4 B'
    "Dm Bb Gm A7 Dm Bb Gm|A7 Dm|C7",          # 5 library
    "F Bb|C7 C F|C7 F Bb|C7 C F|C7",          # 6 fugato
    "Dm D7 Gm C7 F A7 Dm C7",                 # 7 develop
    "Bb C Am Dm Gm Am Bb C7",                 # 8 build
    "F Bb F C Dm Gm C7 F",                    # 9 climax
    "F Bb F|A7 Dm Bb F|D7 Gm|C7 F",           # 10 return
    "Bb F Gm F Bb F C C",                     # 11 outro -> loops to F
]
BAR_CHORDS = [c for sec in HARM for c in sec.split()]
assert len(BAR_CHORDS) == BARS
# How full each section is (0 sparse .. 4 tutti).
DENS = [1, 2, 3, 3, 3, 1, 2, 3, 3, 4, 2, 1]
QUIET = (0, 5, 11)


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


def tones(name):
    off, iv = CH[name]
    return [(KEY + off + i) % 12 for i in iv]


def is_minor(name):
    return CH[name][1][1] == 3


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
# Notes are (degree, beats) or (degree, beats, accidental); degree None = rest.
# The town tune (horn, bars 8-15): the motif as a march melody.
A_TUNE = bars(
    [(0, 1.5), (1, .5), (2, 1), (4, 1)],                     # F    the motif
    [(5, 1.5), (4, .5), (3, 1.5), (5, .5)],                  # Bb
    [(4, 1), (2, 1), (0, 1.5), (2, .5)],                     # F
    [(1, 2), (-1, 1.5), (-3, .5)],                           # C
    [(0, 1.5), (1, .5), (2, 1), (5, 1)],                     # Dm   the hand opens wider
    [(7, 1.5), (5, .5), (4, .5), (3, .5), (1, 1)],           # Gm
    [(4, 1.5), (3, .5), (1, 1), (-1, 1)],                    # C7
    [(0, 3), (None, 1)],                                     # F
)
# The tune again with secondary dominants (oboe, bars 16-23; clarinet at the return).
A2_TUNE = bars(
    [(0, 1.5), (1, .5), (2, 1), (4, 1)],                     # F
    [(5, 1), (7, .5), (5, .5), (3, .5), (4, .5), (5, 1)],    # Bb
    [(4, 1), (2, 1), (1, .5), (-1, .5), (-3, 1, 1)],         # F | A7  (C#)
    [(-2, 1), (0, .5), (2, .5), (5, 2)],                     # Dm
    [(5, 1), (4, .5), (3, .5), (2, 1), (3, 1)],              # Bb
    [(4, 1), (0, 1), (2, 1), (0, 1, 1)],                     # F | D7  (F#)
    [(1, 1), (3, 1), (4, 1), (3, .5), (-1, .5)],             # Gm | C7
    [(0, 3), (None, 1)],                                     # F
)
# The market, in C (degrees in C major): the motif in diminution, chattered.
B_CL = bars(  # clarinet, key C4
    [(-3, .5), (0, .5), (1, .25), (2, .25), (4, .5), (None, 2)],      # C
    [(2, .5), (5, .5), (6, .25), (7, .25), (9, .5), (None, 2)],       # Am
    [(5, .5), (8, .5), (9, .25), (10, .25), (12, .5), (None, 2)],     # Dm
    [(8, .5), (7, .5), (6, .5), (4, .5), (None, 2)],                  # G7
)
B_BSN = bars(  # bassoon answers, key C3
    [(None, 2), (4, .5), (3, .25), (2, .25), (1, .5), (0, .5)],
    [(None, 2), (5, .5), (4, .25), (2, .25), (0, .5), (2, .5)],
    [(None, 2), (1, .5), (3, .25), (5, .25), (4, .5), (3, .5)],
    [(None, 2), (-3, .5), (-1, .5), (1, .5), (3, .5)],
)
B_OB = bars(  # oboe over the chatter, key C5
    [(2, 2), (4, 1), (2, 1)],                                # C
    [(0, 1.5), (-2, .5), (-3, 1), (0, 1)],                   # Am
    [(1, 1), (3, 1, 1), (5, 1), (3, .5, 1), (1, .5)],        # D7 (F#)
    [(-1, 2), (-3, 1), (-4, 1)],                             # G7
)
B2_FL = bars(  # flute, key C5, clarinet a third or so below
    [(-3, .5), (0, .5), (1, .25), (2, .25), (4, .5), (5, .5), (4, .5), (2, .5), (0, .5)],  # C
    [(2, .5), (5, .5), (6, .25), (7, .25), (9, .5), (7, 1), (5, 1)],    # Am
    [(3, 1), (5, .5), (7, .5), (8, 1), (7, 1)],                         # F
    [(6, 1.5), (4, .5), (3, 1), (1, 1)],                                # G7
    [(2, 1), (4, 1), (4, .5), (7, .5, 1), (9, 1)],                      # Em | A7 (C#)
    [(8, 1.5), (7, .5), (5, 1), (3, 1)],                                # Dm
    [(4, 1), (6, 1), (8, 1), (10, 1)],                                  # G7
    [(9, 1.5), (7, .5), (6, .5, -1), (4, .5), (2, 1)],                  # C7 (Bb)
)
# The library (D minor, key D4): the motif inverted and augmented -- the hand
# turned palm-down -- then a rising answer. Bars 40-47.
LIB = [(4, 2), (0, 3), (-1, 1), (-2, 2), (-4, 4)] + bars(          # A D C Bb G (3 bars)
    [(-3, 1), (-1, 1, 1), (1, 1), (3, 1)],                   # A7  A C# E G
    [(2, 1.5), (1, .5), (0, 2)],                             # Dm
    [(None, 1), (5, 1.5), (4, .5), (2, 1)],                  # Bb
    [(3, 1.5), (2, .5), (1, 1), (-1, 1, 1)],                 # Gm | A7
    [(0, 2), (None, 2)],                                     # Dm | C7
)
# The fugato subject (F major): the motif in quick notes, then a bustling tail.
SUBJECT = bars(
    [(-3, .5), (0, 1), (1, .5), (2, .5), (4, 1.5)],          # F       C F G A C
    [(3, .5), (2, .5), (1, .5), (2, .5), (0, 1), (-1, .5), (-3, .5)],  # Bb | C7
)
BUILD = bars(  # flute (clarinet an octave below), bars 64-71
    [(3, 1.5), (4, .5), (5, 2)],                             # Bb
    [(4, 1.5), (5, .5), (6, 2)],                             # C
    [(6, 1.5), (5, .5), (4, 1), (6, 1)],                     # Am
    [(7, 1.5), (6, .5), (5, 1), (9, 1)],                     # Dm
    [(8, 1.5), (7, .5), (5, 1), (10, 1)],                    # Gm
    [(9, 1.5), (8, .5), (6, 1), (11, 1)],                    # Am
    [(12, 2), (10, 1), (8, 1)],                              # Bb
    [(10, 1), (9, .5), (8, .5), (6, 1), (4, 1)],             # C7
)
GROWN_BAR = [(0, 1), (1, .5), (2, .5), (4, 1), (7, 1)]       # M.GROWN in one bar of 4/4
CLIMAX = GROWN_BAR + A_TUNE[4:]                              # then the town tune from bar 2
OUTRO = bars(
    [(None, 1), (5, 1.5), (4, .5), (3, 1)],                  # Bb
    [(2, 3), (None, 1)],                                     # F
    [(None, 1), (3, 1.5), (2, .5), (1, 1)],                  # Gm
    [(0, 3), (None, 1)],                                     # F
    [(None, 3), (-3, 1)],                                    # Bb
    [(0, 1.5), (1, .5), (2, 1), (4, 1)],                     # F   the motif's question...
    [(4, 4)],                                                # C   ...left open on C
    [(None, 4)],                                             # C
)
INTRO_HORN = bars(
    [(None, 4)], [(None, 3), (-3, 1)],                       # F F
    [(0, 3), (1, 1)], [(2, 2), (4, 2)],                      # Bb F  the motif, broad, from afar
    [(None, 4)], [(None, 4)],                                # Gm Bb
    [(1, 2), (-1, 2)], [(None, 3), (-3, 1)],                 # C C   pickup into the tune
)
INTRO_OB = bars([(8, 2), (10, 1), (9, 1)], [(8, 1.5), (7, .5), (5, 2)])   # Gm Bb


def note_parts(n):
    return (n[0], n[1], n[2] if len(n) > 2 else 0)


def realise(t, notes, key, scale=SCALE, shift=0):
    """[(t, beats, pitch)] for a phrase starting at beat t (rests skipped)."""
    out = []
    for n in notes:
        d, b, acc = note_parts(n)
        if d is not None:
            out.append((t, b, M.pitch(d + shift, key, scale) + acc))
        t += b
    return out


REG = []  # every melody note (t0, t1, pitch), for the counter-lines to listen to


def sounding(t, exclude_ch=None):
    return [p for t0, t1, p, ch in REG if t0 <= t + 1e-6 < t1 and ch != exclude_ch]


def harm_below(line, t_key, scale=SCALE):
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
            sc = M.SCALES[scale]
            pcs = [(t_key + s) % 12 for s in sc]
            below = [q for q in range(p - 4, p - 2) if q % 12 in pcs]
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
        elif style == "eighths":
            dur = 0.5
        else:
            dur = rnd.choice([1, 1, 1, 2]) if abs(bib % 2) < 1e-6 else 1.0
            if bib >= 2 and abs(bib - 2) < 1e-6 and rnd.random() < 0.3:
                dur = 1.5
        dur = min(dur, t1 - t)
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


# --------------------------------------------------------------- melody
def build_melody():
    rnd = random.Random(303)
    REG.clear()
    s = Song(BPM, BPB)
    HORN, OBOE, FLUTE, CLAR, BSN, TPT, HORN2 = 0, 1, 2, 3, 4, 5, 6
    s.program(HORN, GM["horn"], vol=100, pan=50, reverb=62)
    s.program(OBOE, GM["oboe"], vol=84, pan=76, reverb=60)
    s.program(FLUTE, GM["flute"], vol=86, pan=84, reverb=66)
    s.program(CLAR, GM["clarinet"], vol=88, pan=40, reverb=60)
    s.program(BSN, GM["bassoon"], vol=92, pan=28, reverb=55)
    s.program(TPT, GM["trumpet"], vol=88, pan=58, reverb=62)
    s.program(HORN2, GM["horn"], vol=82, pan=70, reverb=62)
    breath = {HORN: 1.0, HORN2: 1.0, TPT: 0.9, OBOE: 0.8, FLUTE: 0.8, CLAR: 0.8, BSN: 0.7}

    def play(ch, line, vel=78, legato=0.9, swell=True):
        """Play a realised line [(t, beats, pitch)]."""
        for t, b, p in line:
            v = vel + rnd.randint(-4, 4) + (5 if b >= 2 else 0)
            v += 5 if abs(t % 2) < 1e-6 else (2 if abs(t % 1) < 1e-6 else -3)   # march accents
            lg = legato if b >= 0.5 else 0.8                                     # quick notes detached
            st = t + rnd.uniform(-0.008, 0.008)
            s.note(ch, p, st, b * lg, v)
            REG.append((t, t + b, p, ch))
            if b >= 1.5 and swell:
                s.ramp(ch, 11, 90, 124, st, st + b * 0.5, 5)
                s.ramp(ch, 11, 124, 96, st + b * 0.55, st + b * lg, 5)
                if ch in (OBOE, FLUTE, CLAR):
                    s.ramp(ch, 1, 0, int(26 * breath[ch]), st + 0.4, st + b * 0.85, 4)
                    s.cc(ch, 1, 0, st + b)
            else:
                s.cc(ch, 11, 112, st)

    # 0 intro: the horn calls from afar, the oboe replies.
    play(HORN, realise(bt(0), INTRO_HORN, KEY), vel=64, legato=0.96)
    play(OBOE, realise(bt(4), INTRO_OB, KEY), vel=60, legato=0.95)
    # 1 A: the town tune on horn; a soft clarinet second in the second half.
    a = realise(bt(8), A_TUNE, KEY)
    play(HORN, a, vel=80)
    play(CLAR, harm_below([n for n in a if n[0] >= bt(12)], KEY), vel=56)
    # 2 A': oboe, flute doubling at the octave from bar 20, horn counter-line.
    play(OBOE, realise(bt(15, 3), [(-3, 1)], KEY), vel=66)
    a2 = realise(bt(16), A2_TUNE, KEY)
    play(OBOE, a2, vel=78)
    play(FLUTE, [(t, b, p + 12) for t, b, p in a2 if t >= bt(20)], vel=66)
    play(HORN, counter(rnd, bt(16), bt(24), 55, 67, HORN, "halves"), vel=58, legato=0.97)
    # 3 B: the market in C. Clarinet and bassoon chatter, then an oboe line.
    play(CLAR, realise(bt(24), B_CL, 60), vel=74, legato=0.85)
    play(BSN, realise(bt(24), B_BSN, 48), vel=76, legato=0.8)
    play(OBOE, realise(bt(28), B_OB, 72), vel=76)
    play(BSN, [n for n in counter(rnd, bt(28), bt(32), 43, 57, BSN, "eighths")
               if (n[0] % BPB) >= 2], vel=58, legato=0.6)
    play(HORN, counter(rnd, bt(28), bt(32), 55, 67, HORN, "halves"), vel=54, legato=0.97)
    # 4 B': flute in C, clarinet in thirds below, back home via A7 and C7.
    b2 = realise(bt(32), B2_FL, 72)
    play(FLUTE, b2, vel=74)
    play(CLAR, harm_below(b2, 60), vel=62)
    play(BSN, counter(rnd, bt(32), bt(40), 41, 55, BSN, "quarters"), vel=58, legato=0.75)
    # 5 library: clarinet alone, the inverted motif, slow.
    play(CLAR, realise(bt(40), LIB, 62, "aeolian"), vel=64, legato=0.97)
    # 6 fugato: subject (F) and tonal answer (C) entering voice by voice.
    entries = [(BSN, 53, 0, 48), (CLAR, 65, 4, 50), (OBOE, 77, 0, 52), (FLUTE, 77, 4, 54)]
    ranges = {BSN: (41, 60), CLAR: (55, 74), OBOE: (65, 82)}
    for ch, key, shift, bar in entries:
        play(ch, realise(bt(bar), SUBJECT, key, shift=shift), vel=72 + (bar - 48), legato=0.85)
    for ch, key, shift, bar in entries[:3]:   # after its entry each voice runs on in counterpoint
        lo, hi = ranges[ch]
        play(ch, counter(rnd, bt(bar + 2), bt(56), lo, hi, ch, "quarters"), vel=60, legato=0.8)
    # 7 develop: the motif sequenced, horn calling, oboe answering down the chord.
    for k, bar in enumerate(range(56, 64)):
        name = BAR_CHORDS[bar]
        if k % 2 == 0:
            r = in_range(root_pc(name), 60)
            iv = [(-5, .5), (0, 1), (2, .5), (3 if is_minor(name) else 4, .5), (7, 1.5)]
            ch, vel = HORN, 78
        else:
            r = in_range(root_pc(name), 69)
            iv = [(10, .5), (7, .5), (4, 1), (2, .5), (0, 1.5)]
            ch, vel = OBOE, 74
        t = bt(bar)
        line = []
        for semi, b in iv:
            line.append((t, b, r + semi))
            t += b
        play(ch, line, vel=vel, legato=0.88)
    play(BSN, counter(rnd, bt(56), bt(64), 41, 57, BSN, "quarters"), vel=62, legato=0.7)
    play(CLAR, counter(rnd, bt(56), bt(64), 57, 70, CLAR, "halves"), vel=52, legato=0.95)
    # 8 build: flute rising, clarinet an octave below, horn counter-line.
    bl = realise(bt(64), BUILD, KEY)
    play(FLUTE, bl, vel=74)
    play(CLAR, [(t, b, p - 12) for t, b, p in bl], vel=64)
    play(HORN, counter(rnd, bt(64), bt(72), 55, 69, HORN, "halves"), vel=64, legato=0.97)
    play(TPT, realise(bt(71, 3.5), [(-3, .5)], KEY), vel=80)
    # 9 climax: the motif grown on trumpet, horns a third below, flute above.
    cl = realise(bt(72), CLIMAX, KEY)
    play(TPT, cl, vel=88)
    play(HORN, harm_below(cl, KEY), vel=74)
    play(HORN2, [(t, b, p - 12) for t, b, p in cl], vel=60)
    play(FLUTE, [(t, b, p + 12) for t, b, p in cl], vel=64)
    play(OBOE, counter(rnd, bt(72), bt(80), 69, 81, OBOE, "halves"), vel=56, legato=0.97)
    # 10 return: the tune again, gentler, clarinet with a horn second.
    play(CLAR, realise(bt(79, 3), [(-3, 1)], KEY), vel=60)
    rt = realise(bt(80), A2_TUNE, KEY)
    play(CLAR, rt, vel=72)
    play(HORN, harm_below(rt, KEY), vel=54, legato=0.94)
    # 11 outro: fragments, then the question left open on C.
    play(HORN, realise(bt(88), OUTRO, KEY), vel=66, legato=0.95)
    play(OBOE, realise(bt(89, 2.5), [(4, .5), (5, .5), (4, 1)], KEY), vel=50)
    play(FLUTE, realise(bt(91, 2.5), [(2, .5), (1, .5), (0, 1)], KEY + 12), vel=48)
    return s


# --------------------------------------------------------------- base
def build_base():
    rnd = random.Random(31)
    s = Song(BPM, BPB)
    s.program(0, GM["strings"], vol=72, pan=56, reverb=72, chorus=16)
    s.program(1, GM["cello"], vol=76, pan=76, reverb=55)
    s.program(2, GM["contrabass"], vol=66, pan=64, reverb=45)
    s.program(3, GM["horn"], vol=56, pan=40, reverb=70)
    s.program(4, GM["trombone"], vol=58, pan=48, reverb=65)
    s.program(5, GM["slow_strings"], vol=60, pan=84, reverb=80)
    for bar in range(BARS):
        sec, sbar = section_of(bar)
        b = bt(bar)
        quiet = sec in QUIET
        for cb, cd, name in chords_in(bar):
            t0 = b + cb
            # Strings: a wide voicing, a swell through each chord.
            vel = 40 if quiet else (56 if sec == 9 else 48)
            s.chord(0, voicing(name, 53, 74, 4 if quiet else 5), t0, cd - 0.05, vel)
            s.ramp(0, 11, 74, 118, t0, t0 + cd * 0.55, 6)
            s.ramp(0, 11, 118, 90, t0 + cd * 0.6, t0 + cd - 0.05, 6)
            # High violins hold the chord's top in the fuller sections.
            if DENS[sec] >= 3:
                top = voicing(name, 74, 86, 2)
                s.chord(5, top, t0, cd - 0.05, 38)
            # Cello: roots; in time, a march two-feel with a step into the next chord.
            r = in_range(root_pc(name), 36)
            if quiet or cd < BPB:
                s.note(1, r, t0, cd - 0.1, 56)
            else:
                fifth = r + 7 if r + 7 <= 55 else r - 5
                s.note(1, r, t0, 1.9, 60)
                s.note(1, fifth, t0 + 2, 1.4, 50)
                nr = in_range(root_pc(chords_in(bar + 1)[0][2]), 36)
                step = nr - 1 if nr > fifth else nr + 2
                s.note(1, step if 33 <= step <= 57 else fifth, t0 + 3.5, 0.45, 44)
            if not quiet:
                s.note(2, r - 12 if r - 12 >= 28 else r, t0, cd - 0.1, 50 if sec != 9 else 58)
            # A soft horn pad: third and fifth, in the tune sections.
            if sec in (1, 2, 4, 9, 10):
                pad = voicing(name, 53, 65, 2)
                s.chord(3, pad, t0, cd - 0.08, 44 + rnd.randint(-3, 3))
                s.ramp(3, 11, 70, 112, t0, t0 + cd * 0.5, 4)
                s.ramp(3, 11, 112, 80, t0 + cd * 0.5, t0 + cd - 0.08, 4)
            # Low brass chorale in the build and climax.
            if sec in (8, 9):
                s.chord(4, voicing(name, 43, 58, 3), t0, cd - 0.08, 50 if sec == 8 else 58)
    return s


# --------------------------------------------------------------- rhythm
def build_rhythm():
    rnd = random.Random(41)
    s = Song(BPM, BPB)
    s.program(9, 0, vol=88, reverb=38)
    s.program(0, GM["harpsichord"], vol=60, pan=36, reverb=50)
    s.program(1, GM["tuba"], vol=84, pan=60, reverb=45)
    s.program(2, GM["pizz"], vol=80, pan=78, reverb=50)
    KICK, SNARE, STICK, TRI, TRI_M, WOOD_H, WOOD_L, CRASH, RIDE = 36, 38, 37, 81, 80, 76, 77, 49, 51

    def hit(n, b, v, d=0.2):
        s.note(9, n, b + rnd.uniform(-0.01, 0.01), d, v + rnd.randint(-4, 4))

    for bar in range(BARS):
        sec, sbar = section_of(bar)
        d = DENS[sec]
        b = bt(bar)
        fill = sbar == 7 and d >= 2
        # March kit.
        if d == 1:
            hit(STICK, b + 1, 24)
            hit(STICK, b + 3, 26)
            if sbar % 2 == 0:
                hit(TRI_M, b, 22)
        if d >= 2:
            hit(KICK, b, 52)
            hit(KICK, b + 2, 40)
            pat = [(0, 44), (1, 30), (1.75, 18), (2, 38), (3, 32), (3.5, 22)]
            if d >= 3:
                pat += [(0.5, 20), (2.5, 22), (3.75, 18)]
            for pos, v in pat:
                if fill and pos >= 2:
                    continue
                hit(SNARE if d >= 3 else STICK, b + pos, v + (6 if d == 4 else 0))
        if d >= 3 and sbar % 2 == 0:
            hit(TRI, b, 30)
        if d == 4:
            hit(TRI, b + 2, 26)
            if sbar == 0:
                hit(CRASH, b, 50, 2.0)
        if sec == 5:   # the library clock, and a soft pizzicato walk
            for k in range(4):
                hit(WOOD_L, b + k, 20 if k % 2 else 26)
            for cb, cd, name in chords_in(bar):
                vo = voicing(name, 50, 64, 3)
                walk = [vo[0], vo[1], vo[2], vo[1]]
                for k in range(int(cd)):
                    s.note(2, walk[k % 4], b + cb + k + rnd.uniform(-0.01, 0.01), 0.4,
                           (46 if k == 0 else 36) + rnd.randint(-3, 3))
        if sec == 6:   # the workshop's clockwork
            for k in range(4):
                hit(WOOD_H if k % 2 == 0 else WOOD_L, b + k, 34)
        if fill:
            for k in range(8):   # a snare roll rising into the next section
                s.note(9, SNARE, b + 2 + k * 0.25 + rnd.uniform(-0.008, 0.008), 0.15, 20 + k * 5)
        if bar == 71:
            for k in range(16):
                s.note(9, RIDE, b + k * 0.25, 0.2, 18 + k * 3)
        # Tuba oom on 1 and 3; pizzicato pah on 2 and 4.
        for cb, cd, name in chords_in(bar):
            r = in_range(root_pc(name), 34)
            if d >= 2:
                s.note(1, r, b + cb, 0.7, 70 + rnd.randint(-4, 4))
                if cd >= BPB:
                    s.note(1, r + 7 if r + 7 <= 48 else r - 5, b + cb + 2, 0.7, 58)
                    if d >= 3 and sbar % 2 == 1:
                        nr = in_range(root_pc(chords_in(bar + 1)[0][2]), 34)
                        s.note(1, nr - 2 if nr > r else nr + 2, b + cb + 3.5, 0.4, 48)
                vo = voicing(name, 55, 69, 3)
                for off in (1, 3):
                    if off < cd:
                        s.chord(2, vo, b + cb + off, 0.3, 48 + rnd.randint(-4, 4))
            elif sec != 5:
                s.note(1, r, b + cb, cd * 0.5, 50)
        # Harpsichord: bustling broken chords.
        if d >= 2 and sec != 5:
            for cb, cd, name in chords_in(bar):
                vo = voicing(name, 60, 79, 4)
                alberti = [vo[0], vo[2], vo[1], vo[2]] if len(vo) >= 3 else vo
                steps = int(cd * 2)
                for k in range(steps):
                    pos = b + cb + k * 0.5
                    v = 46 if k % 4 == 0 else 36
                    s.note(0, alberti[k % 4], pos + rnd.uniform(-0.006, 0.006), 0.45, v + rnd.randint(-3, 3))
                    if d >= 3 and k % 4 == 3:   # a turning sixteenth pair
                        s.note(0, vo[-1], pos + 0.25, 0.2, v - 6)
    return s


# --------------------------------------------------------------- colour
def plain_hunt(bells, rows):
    """Change-ringing plain hunt: rounds, then swap pairs, alternating."""
    row = list(bells)
    out = []
    for i in range(rows):
        out.append(list(row))
        start = 0 if i % 2 == 0 else 1
        for k in range(start, len(row) - 1, 2):
            row[k], row[k + 1] = row[k + 1], row[k]
    return out


def build_colour():
    rnd = random.Random(55)
    s = Song(BPM, BPB)
    BELLS, GLOCK, PIANO, PICC, CHOIR = 0, 1, 2, 3, 4
    s.program(BELLS, GM["bells"], vol=74, pan=66, reverb=92)
    s.program(GLOCK, GM["glock"], vol=60, pan=30, reverb=80)
    s.program(PIANO, GM["piano"], vol=80, pan=52, reverb=70)
    s.program(PICC, GM["piccolo"], vol=58, pan=88, reverb=78)
    s.program(CHOIR, GM["oohs"], vol=60, pan=56, reverb=90)
    # Six church bells on F major's pentatonic notes, so every change sits on the harmony.
    six = [77, 74, 72, 69, 67, 65]   # F5 D5 C5 A4 G4 F4

    def ring(t0, rows, step, vel, method="hunt"):
        rs = plain_hunt(six, rows) if method == "hunt" else [six] * rows
        t = t0
        for row in rs:
            for k, p in enumerate(row):
                v = vel + rnd.randint(-5, 5) + (6 if k == 0 else 0)
                s.note(BELLS, p, t + rnd.uniform(-0.02, 0.02), 3.0, v)
                t += step
            t += step   # the open handstroke gap
        return t

    ring(bt(0), 4, 1.0, 46, "rounds")            # intro: rounds, slow
    ring(bt(72), 8, 0.5, 52)                      # climax: plain hunt in eighths
    ring(bt(88), 2, 1.0, 38, "rounds")            # outro: rounds again, fading
    ring(bt(93), 1, 1.5, 30, "rounds")
    for bar in (8, 24, 48, 80):                   # a single toll at section heads
        s.note(BELLS, 53, bt(bar), 4.0, 48)
    # Glockenspiel echoes of the motif, built on the chord root where the tune rests.
    echoes = [(7, 0, "head"), (11, 2, "tail"), (15, 1, "head"), (23, 1, "tail"),
              (27, 2, "head"), (31, 2, "tail"), (39, 2, "head"), (59, 2, "tail"),
              (63, 2, "head"), (79, 1, "tail"), (87, 1, "head"), (89, 0, "tail"),
              (91, 0, "head"), (95, 0, "motif")]
    for bar, beat, kind in echoes:
        name = chord_at(bt(bar, beat))
        r = in_range(root_pc(name), 77)
        third = 3 if is_minor(name) else 4
        shape = {"head": [(-5, .5), (0, .5), (2, 1)],
                 "tail": [(2, .5), (third, .5), (7, 1)],
                 "motif": [(-5, .5), (0, .75), (2, .25), (third, .5), (7, 1.5)]}[kind]
        t = bt(bar, beat)
        for semi, d in shape:
            s.note(GLOCK, r + semi, t, max(d, 1.0), 50 + rnd.randint(-5, 5))
            t += d
    # Piano: the library's turning pages, and gentle broken chords at the return.
    for bar in range(BARS):
        sec, sbar = section_of(bar)
        b = bt(bar)
        if sec == 5:
            for cb, cd, name in chords_in(bar):
                r = in_range(root_pc(name), 38)
                vo = [r, r + 7] + voicing(name, r + 12, r + 28, 4)
                fig = vo + vo[-2:0:-1]
                for k in range(int(cd * 2)):
                    s.note(PIANO, fig[k % len(fig)], b + cb + k * 0.5, 1.2,
                           42 + (8 if k == 0 else 0) + rnd.randint(-4, 3))
            s.cc(PIANO, 64, 127, b)
            s.cc(PIANO, 64, 0, b + BPB - 0.05)
        elif sec == 10 or (sec in (2, 7) and sbar % 2 == 1):
            for cb, cd, name in chords_in(bar):
                vo = voicing(name, 60, 84, 5)
                for k, p in enumerate(vo):
                    s.note(PIANO, p, b + cb + 0.5 + k * 0.25, cd - 0.6 - k * 0.25, 38 - k * 2 + rnd.randint(-3, 3))
    # Piano sparkle: quick rising chord tones up high, now and then.
    sparkle = [0.0, 0.45, 0.3, 0.5, 0.5, 0.0, 0.4, 0.3, 0.45, 0.0, 0.0, 0.3]
    for bar in range(BARS):
        sec, sbar = section_of(bar)
        if rnd.random() >= sparkle[sec]:
            continue
        cb, cd, name = rnd.choice(chords_in(bar))
        vo = voicing(name, 72, 91, 5)
        start = rnd.choice([0.5, 1, 1.5]) if cd >= BPB else 0.5
        for k in range(rnd.choice([3, 4, 5])):
            s.note(PIANO, vo[k % len(vo)], bt(bar, cb + start + k * 0.25), 1.2,
                   40 + rnd.randint(-5, 3) - k * 2)
    # Piccolo birdsong: a trill on a chord tone, then a little run up.
    for bar in (18, 21, 34, 37, 66, 69, 82, 85):
        name = chord_at(bt(bar, 2))
        p = in_range(tones(name)[0], 84)
        sc = sorted({(KEY + o) % 12 for o in M.SCALES[SCALE]})
        up = next(q for q in range(p + 1, p + 3) if q % 12 in sc)
        t = bt(bar, 2)
        for k in range(6):
            s.note(PICC, up if k % 2 else p, t + k * 0.125, 0.12, 44 + rnd.randint(-4, 4))
        run = [q for q in range(p + 1, p + 9) if q % 12 in tones(name)]
        for k, q in enumerate(run[:3]):
            s.note(PICC, q, t + 0.75 + k * 0.25, 0.25 if k < 2 else 0.8, 46 + k * 3)
    # Soft choir in the climax and the outro.
    for sec in (9, 11):
        for sbar in range(8):
            bar = sec * 8 + sbar
            for cb, cd, name in chords_in(bar):
                b0 = bt(bar, cb)
                s.chord(CHOIR, voicing(name, 57, 72, 3), b0, cd - 0.1, 50 if sec == 9 else 42)
                s.ramp(CHOIR, 11, 40, 108, b0, b0 + cd * 0.5, 5)
                s.ramp(CHOIR, 11, 108, 54, b0 + cd * 0.5, b0 + cd - 0.1, 5)
    return s


# --------------------------------------------------------------- tense
def build_tense():
    rnd = random.Random(66)
    s = Song(BPM, BPB)
    s.program(9, 0, vol=96, reverb=40)
    s.program(0, GM["timpani"], vol=92, reverb=55)
    s.program(1, GM["trombone"], vol=80, pan=50, reverb=50)
    s.program(2, GM["cello"], vol=82, pan=70, reverb=40)
    s.program(3, GM["tremolo"], vol=68, pan=40, reverb=60)
    s.program(4, GM["bells"], vol=64, pan=84, reverb=70)
    s.program(5, GM["contrabass"], vol=74, reverb=40)
    SNARE, FLOOR, LOW_TOM, KICK = 38, 41, 45, 36

    def hit(ch, n, b, v, d=0.2):
        s.note(ch, n, b + rnd.uniform(-0.006, 0.006), d, v + rnd.randint(-4, 4))

    for bar in range(BARS):
        sec, sbar = section_of(bar)
        b = bt(bar)
        # Driving snare sixteenths, accented in a "fire-brigade" gallop.
        for k in range(16):
            acc = k in (0, 3, 6, 8, 11, 14)
            hit(9, SNARE, b + k * 0.25, 46 if acc else 18, 0.12)
        for pos in (0, 1.5, 2, 3.5):
            hit(9, FLOOR if pos in (0, 2) else LOW_TOM, b + pos, 64 if pos == 0 else 48)
        hit(9, KICK, b, 60)
        hit(9, KICK, b + 2, 48)
        for cb, cd, name in chords_in(bar):
            r = in_range(root_pc(name), 36)
            if r > 45:
                r -= 12
            # Cello ostinato: root, root, fifth, root in sixteenths.
            for k in range(int(cd * 4)):
                q = r + 12 + (7 if k % 4 == 2 else 0)
                hit(2, q, b + cb + k * 0.25, 52 if k % 4 == 0 else 36, 0.2)
            hit(5, r, b + cb, 62, min(cd, 2) - 0.1)
            # Trombone stabs: root and fifth, on 1 and the and-of-3.
            for pos, v in ((0, 70), (2.5, 60)):
                if pos < cd:
                    s.chord(1, [r + 12, r + 19], b + cb + pos, 0.4, v + rnd.randint(-4, 4))
            # Tremolo strings swelling on root, fifth and octave.
            s.chord(3, [r + 24, r + 31, r + 36], b + cb, cd - 0.05, 50)
            s.ramp(3, 11, 50, 118, b + cb, b + cb + cd * 0.85, 6)
            if cb == 0 and sbar % 2 == 0:
                hit(0, r, b, 80, 2.0)
        # Timpani roll every four bars.
        if sbar % 4 == 3:
            r = in_range(root_pc(chords_in(bar)[-1][2]), 36)
            r = r - 12 if r > 45 else r
            for k in range(12):
                hit(0, r, b + 1 + k * 0.25, 30 + k * 5, 0.25)
        # The fire bell: two quick strokes, on the chord root high up.
        if sbar % 2 == 0:
            p = in_range(root_pc(chords_in(bar)[0][2]), 72)
            for k in range(2):
                s.note(4, p, b + k * 0.33, 1.5, 56 - k * 10)
    return s


# Stem balance (dB) applied after rendering, so each layer sits right in the mix.
MIX_DB = {"base": 5.2, "rhythm": 2.0, "melody": 0.0, "colour": 5.5, "tense": -1.2}

STEMS = {
    "base": build_base,
    "rhythm": build_rhythm,
    "melody": build_melody,
    "colour": build_colour,
    "tense": build_tense,
}


def era1_full_lufs():
    """Loudness (LUFS) of Era 1's full day mix, so Era 3 can sit at the same level."""
    d = out_path("assets", "audio", "music", "era1")
    try:
        full = sum(read_audio(os.path.join(d, s + ".ogg")) for s in ("base", "rhythm", "melody", "colour"))
    except Exception:  # Era 1 not rendered: fall back to peak normalising
        return None
    return lufs(full)


def main():
    outdir = out_path("assets", "audio", "music", "era3")
    middir = out_path("tools", "music", "midi", "era3")
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
          f"all five {dbfs(peak(everything * g)):.2f} dBFS, "
          f"full {lufs(full * g):.1f} LUFS (Era 1 {'n/a' if target is None else f'{target:.1f}'})")


if __name__ == "__main__":
    main()
