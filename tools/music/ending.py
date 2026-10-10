"""The goodbye: the music of the launch and the ending (DESIGN.md section 9).

Not an adaptive loop: a handful of cues the ending plays in order, following
the beat sheet. The emotional arc is mild and bittersweet, a parent watching
a child leave for university, never a funeral and never a blockbuster. The
cues move from Era 4's G lydian to D, the key of the first night: G lydian
and D major hold exactly the same notes, so the music can step home without
a jolt, and at the very end Era 1's own instruments come back under the
whole motif, so the ending remembers the beginning.

  last_evening   LOOP, 106.7 s  beats 1-4: the last evening, crew selection,
                 the gifts, into the capsule. The music thins: piano alone
                 with a warm pad, the motif slow and spacious, strings and a
                 cello joining later, celesta and Era 1's kalimba remembering.
                 4/4 at 72, G lydian (with Era 2's C natural as a memory).
  countdown      LOOP, 40 s     beat 5: hold Part the Clouds. A steady pulse:
                 a piano ostinato on the open notes E A B, a ticking clock,
                 a soft heartbeat kick, synth bass; the harmony climbs E F#
                 G A and starts again, high violins rising with it, a choir
                 in the second half. Anticipation, not danger. 4/4 at 96.
                 When the player lets go, the game ducks it (Audio.cue_level)
                 instead of stopping it: the countdown pauses gently.
  liftoff        ONE-SHOT, 56 s beat 6: on release. A warm G arrival (no
                 explosion), the motif rising a step at a time over a G
                 pedal as the rocket climbs through the gap; then the full
                 arrangement plays the motif once, grown to the octave and
                 on to the lydian C#, its answer landing on D; then it all
                 drops back to Era 1's drone and the lone pan flute asking
                 the motif's question. 4/4 at 96.
  wave           LOOP, 51.4 s   beats 7-8: the wave, the light. The lone flute
                 (section 13.1): Era 1's own phrases on pan flute, now in D
                 major, over Era 1's drone, strings and cello, kalimba
                 echoes, the people humming. 3/4 at 84, Era 1's metre and
                 tempo.
  goodbye        ONE-SHOT, 73 s beats 8-10: the light blinks twice (two
                 kalimba notes, the motif's first step), Era 1's drone and
                 frame-drum heartbeat; the pan flute plays Era 1's very first
                 phrase exactly, in D dorian; then the lineage: the motif
                 passes from generation to generation, fiddle (Era 2), horn
                 (Era 3), piano (Era 4), all of them, as the harmony brightens
                 to major; then the full motif in D major over Era 1's sound,
                 and its answer, slowly, home. The hand lowers. 3/4 at 84.
  credits        ONE-SHOT, 3:42 "Among the Stars", the credits over the city at
                 night. A song in
                 D major, 4/4 at 76: piano alone; the strings; then memories
                 of every era in turn, each in its own instruments (Era 1's
                 flute phrases in dorian with kalimba and heartbeat, Era 2's
                 village tune on fiddle and lute, Era 3's town tune on horn
                 with bells, Era 4's theme on piano and pads); all of them
                 together, gently; then the lone flute asks the motif's
                 question one last time, a breath of silence, and at last
                 the answer, home on D. Two kalimba notes, the light, once
                 more.

Run:  python3 tools/music/ending.py [cue ...]
"""
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
from common import GM, SR, Song, dbfs, fit_oneshot, lufs, out_path, peak, render_song, seam_loop, write_ogg  # noqa: E402
import motif as M  # noqa: E402

P = dict(GM, ep=4, synth_bass2=39, polysynth=90, crystal=98, tubular=14, aah=52, pad_sweep=95)
PC = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
QUAL = {"": (0, 4, 7), "m": (0, 3, 7), "7": (0, 4, 7, 10), "maj7": (0, 4, 7, 11),
        "m7": (0, 3, 7, 10), "sus": (0, 5, 7), "add9": (0, 4, 7, 14)}
# Era 1's drum kit (GM drum notes): the frame drum is the tribe's heartbeat.
FRAME, FRAME2, LOW_CONGA, OPEN_CONGA, MUTE_CONGA, SHAKER = 41, 43, 64, 63, 62, 70


def pc_of(name):
    p = PC[name[0]]
    if len(name) > 1 and name[1] == "#":
        p += 1
    elif len(name) > 1 and name[1] == "b":
        p -= 1
    return p % 12


def parse_chord(sym):
    """'A/C#' -> (root pc, [chord pcs], bass pc, minor?)."""
    main, _, bass = sym.partition("/")
    i = 2 if len(main) > 1 and main[1] in "#b" else 1
    r = pc_of(main[:i])
    q = main[i:]
    tones = [(r + x) % 12 for x in QUAL[q]]
    return r, tones, (pc_of(bass) if bass else r), q in ("m", "m7")


def nm(s):
    """'C#5' -> MIDI pitch (C4 = 60)."""
    i = 2 if len(s) > 2 and s[1] in "#b" else 1
    return pc_of(s[:i]) + 12 * (int(s[i:]) + 1)


def in_range(pc, lo):
    return lo + (pc - lo) % 12


def third_below(p, tonic_pc, scale="major"):
    """The diatonic third below pitch p (None stays a rest)."""
    if p is None:
        return None
    pcs = [(tonic_pc + x) % 12 for x in M.SCALES[scale]]
    if p % 12 not in pcs:
        return p - 3
    q, steps = p, 0
    while steps < 2:
        q -= 1
        if q % 12 in pcs:
            steps += 1
    return q


class Cue:
    """A Song plus a chord chart, with the accompaniment helpers every cue uses."""

    def __init__(self, bpm, bpb, bars, seed):
        self.s = Song(bpm, bpb)
        self.bpm, self.bpb, self.bars = bpm, bpb, bars
        self.chart = {}
        self.rnd = random.Random(seed)
        self.reg = []  # every melody note (t0, t1, pitch, ch), for checking against the chart

    def bt(self, bar, beat=0.0):
        return bar * self.bpb + beat

    def prog(self, bar0, text):
        for i, tok in enumerate(text.split()):
            self.chart[bar0 + i] = tok

    def chords_in(self, bar):
        tok = self.chart.get(bar % self.bars)
        if tok is None or tok == "-":
            return []
        parts = tok.split("|")
        d = self.bpb / len(parts)
        return [(i * d, d, c) for i, c in enumerate(parts)]

    def chord_at(self, t):
        bar = int(t // self.bpb)
        cs = self.chords_in(bar)
        bib = t - bar * self.bpb
        cs = [c for cb, cd, c in cs if cb <= bib + 1e-6]
        return cs[-1] if cs else None

    def voicing(self, sym, lo=55, hi=72, n=4):
        _, ts, _, _ = parse_chord(sym)
        out = sorted({in_range(pc, lo) for pc in ts})
        k = 0
        while len(out) < n and k < len(out):
            v = out[k] + 12
            if v <= hi and v not in out:
                out.append(v)
            k += 1
        return sorted(out)[:n]

    def each_chord(self, bar0, bar1):
        for bar in range(bar0, bar1):
            for cb, cd, sym in self.chords_in(bar):
                yield bar, self.bt(bar, cb), cd, sym

    # ---- melody
    def line(self, ch, t, notes, vel=76, legato=0.92, swell=True, piano=False, shift=0):
        """Play [(pitch or None, beats)]; returns the end beat."""
        rnd = self.rnd
        for p, b in notes:
            if p is not None:
                v = vel + rnd.randint(-4, 4) + (5 if b >= 2 else 0)
                st = t + rnd.uniform(-0.008, 0.008)
                self.s.note(ch, p + shift, st, b * (1.0 if piano else (legato if b >= 0.5 else 0.82)), v)
                self.reg.append((t, t + b, p + shift, ch))
                if not piano:
                    if b >= 1.5 and swell:
                        self.s.ramp(ch, 11, 88, 126, st, st + b * 0.45, 5)
                        self.s.ramp(ch, 11, 126, 92, st + b * 0.55, st + b * legato, 5)
                    else:
                        self.s.cc(ch, 11, 112, st)
            t += b
        return t

    def deg(self, ch, t, phrase, key, scale="major", **kw):
        return self.line(ch, t, M.realise(phrase, key, scale), **kw)

    def names(self, ch, t, text, **kw):
        """'D5:1 G5:1.5 r:2' -> notes."""
        notes = []
        for tok in text.split():
            n, _, b = tok.partition(":")
            notes.append((None if n == "r" else nm(n), float(b)))
        return self.line(ch, t, notes, **kw)

    def pedal(self, ch, bar0, bar1):
        for bar, t, cd, sym in self.each_chord(bar0, bar1):
            self.s.cc(ch, 64, 0, t - 0.02)
            self.s.cc(ch, 64, 127, t + 0.04)
        self.s.cc(ch, 64, 0, self.bt(bar1) - 0.05)

    # ---- accompaniment
    def pad(self, ch, bar0, bar1, lo=50, hi=67, n=4, vel=50, bass=True):
        for bar, t, cd, sym in self.each_chord(bar0, bar1):
            r, ts, b, _ = parse_chord(sym)
            notes = set(self.voicing(sym, lo, hi, n))
            if bass:
                notes.add(in_range(b, 38))
            self.s.chord(ch, sorted(notes), t, cd - 0.03, vel + self.rnd.randint(-2, 2))

    def strings(self, ch, bar0, bar1, lo=52, hi=74, n=4, vel=48, swell=(72, 118, 90)):
        for bar, t, cd, sym in self.each_chord(bar0, bar1):
            self.s.chord(ch, self.voicing(sym, lo, hi, n), t, cd - 0.05, vel)
            a, b, c = swell
            self.s.ramp(ch, 11, a, b, t, t + cd * 0.55, 6)
            self.s.ramp(ch, 11, b, c, t + cd * 0.6, t + cd - 0.05, 6)

    def roots(self, ch, bar0, bar1, lo=36, vel=54, split=False):
        for bar, t, cd, sym in self.each_chord(bar0, bar1):
            r, ts, b, _ = parse_chord(sym)
            p = in_range(b, lo)
            if split and cd >= self.bpb and self.bpb == 4:
                self.s.note(ch, p, t, 2.9, vel)
                fifth = in_range(r, lo) + 7
                self.s.note(ch, fifth if fifth < lo + 19 else fifth - 12, t + 3, 0.95, vel - 10)
            else:
                self.s.note(ch, p, t, cd - 0.08, vel)

    def arp(self, ch, bar0, bar1, lo=50, step=0.5, vel=38, shape=(0, 1, 2, 3, 2, 1, 2, 1), hi=None):
        """Left-hand broken chords: the bass note, then chord tones up and down."""
        for bar, t, cd, sym in self.each_chord(bar0, bar1):
            r, ts, b, _ = parse_chord(sym)
            low = in_range(b, lo - 12 if lo > 48 else lo)
            vo = [low] + self.voicing(sym, low + 7, (hi or low + 24), 4)
            for k in range(int(round(cd / step))):
                p = vo[shape[k % len(shape)] % len(vo)]
                v = vel + (6 if k == 0 else 0) + self.rnd.randint(-3, 3)
                self.s.note(ch, p, t + k * step + self.rnd.uniform(-0.005, 0.005), step * 1.6, v)

    def drone(self, ch, b0, beats, vel=60, notes=(38, 45), every=None):
        """Era 1's drone: D2 + A2 on the warm pad, restruck now and then."""
        every = every or beats
        t = b0
        while t < b0 + beats - 1e-6:
            d = min(every, b0 + beats - t)
            for i, p in enumerate(notes):
                self.s.note(ch, p, t, d - 0.02, vel - 10 * i)
            t += d

    def heartbeat(self, bar0, bar1, vel=56):
        """Era 1's frame-drum heartbeat (its quietest rhythm, section 0)."""
        rnd = self.rnd
        for bar in range(bar0, bar1):
            b = self.bt(bar)
            v = vel + rnd.randint(-5, 5)
            if bar % 2 == 0:
                self.s.note(9, FRAME, b, 0.25, v)
                self.s.note(9, FRAME, b + self.bpb - 0.5, 0.25, int(v * 0.6))
            else:
                self.s.note(9, FRAME2, b, 0.25, int(v * 0.7))

    def echo(self, ch, t, phrase, key, scale="major", vel=54, shift=0):
        """Kalimba-style echo: notes ring at least a beat."""
        for p, d in M.realise(phrase, key, scale, shift):
            if p is not None:
                self.s.note(ch, p, t, max(d, 1.0), vel + self.rnd.randint(-5, 5))
            t += d


# ===================================================================== cues
def last_evening():
    c = Cue(72, 4, 32, 101)
    s = c.s
    PNO, LH, PAD, STR, CEL, CELLO, KAL, BOX = 0, 1, 2, 3, 4, 5, 6, 7
    s.program(PNO, P["piano"], vol=98, pan=62, reverb=74)
    s.program(LH, P["piano"], vol=76, pan=50, reverb=74)
    s.program(PAD, P["pad_warm"], vol=66, reverb=86, chorus=40)
    s.program(STR, P["slow_strings"], vol=62, pan=70, reverb=86)
    s.program(CEL, P["celesta"], vol=62, pan=30, reverb=86)
    s.program(CELLO, P["cello"], vol=66, pan=76, reverb=66)
    s.program(KAL, P["kalimba"], vol=70, pan=88, reverb=82)
    s.program(BOX, P["music_box"], vol=58, pan=80, reverb=88)
    c.prog(0, "Gmaj7 A/G Bm7 Em7 Cmaj7 G/B Am7 D")
    c.prog(8, "Gmaj7 A/G F#m7 Bm7 Em7 A Dsus D")
    c.prog(16, "Cmaj7 D/C Bm7 Em7 Am7 D G/B Cmaj7")
    c.prog(24, "Gmaj7 A/G Em7 Bm7 Cmaj7 Am7 Dsus D")
    # The piano: the motif, slow and spacious, like something remembered.
    tune = [
        "r:3 D5:1", "G5:2 A5:1 B5:1", "D6:3 r:1", "r:1 E6:1 D6:1 B5:1",
        "B5:2 A5:1 G5:1", "G5:2 F#5:1 D5:1", "E5:3 r:1", "r:2 E5:1 F#5:1",
        "G5:3 r:1", "r:1 A5:1 C#6:1 E6:1", "E6:2 C#6:1 A5:1", "B5:3 r:1",
        "r:1 G5:1 B5:1 D6:1", "C#6:3 B5:1", "A5:2 G5:2", "F#5:3 r:1",
        "E5:1 G5:1 B5:2", "A5:2 F#5:2", "D5:1 F#5:1 A5:2", "G5:3 r:1",
        "C6:2 B5:1 A5:1", "A5:2 F#5:1 D5:1", "D5:1 G5:1.5 A5:.5 B5:1", "D6:3 r:1",
        "r:4", "D6:1 C#6:.5 B5:.5 A5:2", "G5:3 r:1", "r:2 F#5:1 D5:1",
        "E5:2 G5:2", "A5:2 G5:1 E5:1", "r:1 A4:1 D5:2", "r:4",
    ]
    for bar, text in enumerate(tune):
        c.names(PNO, c.bt(bar), text, vel=60, piano=True)
    c.pedal(PNO, 0, 32)
    # Left hand: a slow rocking broken chord.
    c.arp(LH, 0, 32, lo=43, step=0.5, vel=34, shape=(0, 2, 3, 4, 1, 3, 2, 4))
    c.pedal(LH, 0, 32)
    c.pad(PAD, 0, 32, 50, 67, 3, vel=42)
    c.strings(STR, 8, 32, 55, 74, 4, vel=34)
    c.roots(CELLO, 16, 32, 36, vel=46)
    # Era 1's kalimba remembers the motif in the rests; celesta and music box stars.
    c.echo(KAL, c.bt(24, 1), M.HEAD, 79, "lydian", vel=50)
    c.echo(KAL, c.bt(31, 1), M.TAIL, 79, "lydian", vel=46)
    c.echo(KAL, c.bt(7, 2), [(1, .5), (2, .5)], 79, "lydian", vel=40)
    for bar in (3, 11, 15, 19, 27):
        sym = c.chords_in(bar)[0][2]
        vo = c.voicing(sym, 81, 96, 4)
        for k, p in enumerate(vo[:3]):
            s.note(CEL if bar % 2 else BOX, p, c.bt(bar, 2 + k * 0.5), 1.5, 42 - k * 3)
    return c, None


def countdown():
    c = Cue(96, 4, 16, 202)
    s = c.s
    PNO, SB, STR, HIGH, CELLO, CHOIR, PAD, TIMP = 0, 1, 2, 3, 4, 5, 6, 7
    s.program(9, 0, vol=82, reverb=40)
    s.program(PNO, P["piano"], vol=76, pan=40, reverb=64)
    s.program(SB, P["synth_bass2"], vol=66, reverb=30)
    s.program(STR, P["strings"], vol=72, pan=60, reverb=78)
    s.program(HIGH, P["slow_strings"], vol=70, pan=80, reverb=84)
    s.program(CELLO, P["cello"], vol=74, pan=70, reverb=60)
    s.program(CHOIR, P["aah"], vol=56, reverb=92)
    s.program(PAD, P["polysynth"], vol=52, pan=50, reverb=84, chorus=60)
    s.program(TIMP, P["timpani"], vol=80, reverb=70)
    c.prog(0, "Em7 Em7 F#m7 F#m7 Gmaj7 Gmaj7 Asus A")
    c.prog(8, "Em7 Em7 F#m7 F#m7 Gmaj7 Gmaj7 Bm7 Asus|A")
    rnd = c.rnd
    # The ostinato: open notes that sit on every chord, ticking like a clock.
    osti = [nm("E5"), nm("A5"), nm("B5"), nm("A5")]
    for bar in range(16):
        for k in range(8):
            v = (40 if k % 2 == 0 else 32) + (4 if bar >= 8 else 0) + rnd.randint(-3, 3)
            s.note(PNO, osti[k % 4], c.bt(bar, k * 0.5), 0.45, v)
        b = c.bt(bar)
        s.note(9, 36, b, 0.3, 48 + rnd.randint(-3, 3))           # heartbeat kick
        s.note(9, 36, b + 0.75, 0.3, 30)
        for k in range(4):
            s.note(9, 76 if k % 2 == 0 else 77, b + k, 0.1, 30 + rnd.randint(-3, 3))   # the clock
        if bar >= 8:
            for k in range(8):
                s.note(9, 42, b + k * 0.5 + 0.25, 0.1, 18 + rnd.randint(-3, 3))
    for bar, t, cd, sym in c.each_chord(0, 16):
        r, ts, bp, _ = parse_chord(sym)
        for k in range(int(cd * 2)):
            s.note(SB, in_range(bp, 28), t + k * 0.5, 0.36, 56 if k % 2 == 0 else 44)
    # Strings hold each chord across two bars, swelling.
    for bar in range(0, 16, 2):
        sym = c.chords_in(bar)[0][2]
        t = c.bt(bar)
        s.chord(STR, c.voicing(sym, 52, 71, 4), t, 7.9, 50)
        s.ramp(STR, 11, 60, 118, t, t + 6, 8)
        s.ramp(STR, 11, 118, 80, t + 6.5, t + 7.9, 3)
        s.chord(PAD, c.voicing(sym, 60, 76, 4), t, 7.9, 40)
        s.note(CELLO, in_range(parse_chord(sym)[2], 40), t, 7.9, 56)
    # High violins climb with the bass: B, C#, D, E -- and start again.
    for half in (0, 8):
        for k, p in enumerate(("B5", "C#6", "D6", "E6")):
            t = c.bt(half + 2 * k)
            s.note(HIGH, nm(p), t, 7.9, 44 + 4 * k)
            s.ramp(HIGH, 11, 50, 120, t, t + 7, 8)
    for bar in range(8, 16, 2):
        sym = c.chords_in(bar)[0][2]
        t = c.bt(bar)
        s.chord(CHOIR, c.voicing(sym, 57, 72, 3), t, 7.9, 44)
        s.ramp(CHOIR, 11, 40, 112, t, t + 6, 6)
    for bar in (7, 15):
        r = in_range(parse_chord(c.chords_in(bar)[-1][2])[0], 40)
        for k in range(12):
            s.note(TIMP, r, c.bt(bar, 1) + k * 0.25, 0.25, 22 + k * 4)
    return c, None


def liftoff():
    c = Cue(96, 4, 22, 303)
    s = c.s
    PNO, HORN, VLN, FLUTE, CHOIR, STR, PAD, CB, TIMP, PANF, KAL, HARP, PNO2 = 0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13
    s.program(9, 0, vol=80, reverb=60)
    s.program(PNO, P["piano"], vol=100, pan=60, reverb=70)
    s.program(PNO2, P["piano"], vol=80, pan=48, reverb=70)
    s.program(HORN, P["horn"], vol=92, pan=42, reverb=74)
    s.program(VLN, P["strings"], vol=92, pan=72, reverb=80)
    s.program(FLUTE, P["flute"], vol=80, pan=84, reverb=80)
    s.program(CHOIR, P["aah"], vol=70, reverb=94)
    s.program(STR, P["slow_strings"], vol=80, pan=56, reverb=86)
    s.program(PAD, P["pad_warm"], vol=78, reverb=88, chorus=40)
    s.program(CB, P["contrabass"], vol=78, reverb=60)
    s.program(TIMP, P["timpani"], vol=88, reverb=74)
    s.program(PANF, P["pan_flute"], vol=94, pan=60, reverb=86, chorus=10)
    s.program(KAL, P["kalimba"], vol=74, pan=86, reverb=84)
    s.program(HARP, P["harp"], vol=78, pan=34, reverb=82)
    G = 67
    c.prog(0, "G G G A/G Gmaj7 A/G Bm Bm")
    c.prog(8, "G A/G Bm Em Cmaj7 A D D")
    c.prog(16, "- - - - - -")
    # Release: a warm G arrival. Timpani and a soft cymbal, no explosion.
    s.note(TIMP, 43, 0, 3.0, 92)
    s.note(9, 49, 0, 4.0, 52)
    s.note(9, 52, 0.02, 4.0, 30)
    for k in range(40):     # the engines: a low rolling swell under the climb
        s.note(TIMP, 43, 1.5 + k * 0.25, 0.25, int(18 + 22 * (1 - abs(k - 20) / 20)))
    s.note(CB, 31, 0, 31.8, 66)
    s.note(PAD, 31, 0, 31.8, 60)
    c.pad(PAD, 0, 16, 50, 67, 4, vel=56, bass=False)
    c.strings(STR, 0, 16, 55, 76, 5, vel=54)
    s.chord(CHOIR, [55, 62, 67, 71], 0, 7.8, 58)
    s.ramp(CHOIR, 11, 100, 60, 0, 7.8, 6)
    # The climb: the motif a step higher each time, as the rocket rises.
    climb = [(2, VLN, 0, 66), (4, HORN, 2, 70), (6, PNO, 4, 72)]   # bar, ch, shift (scale steps), vel
    for bar, ch, shift, vel in climb:
        t = c.bt(bar) - 1
        notes = M.realise(M.MOTIF, G, "lydian", shift)
        c.line(ch, t, notes, vel=vel, piano=(ch == PNO), legato=0.95)
        if ch != VLN:
            c.line(VLN, t, [(p + 12, d) for p, d in notes], vel=vel - 10, legato=0.95)
    s.cc(PNO, 64, 127, c.bt(5)), s.cc(PNO, 64, 0, c.bt(8) - 0.05)
    for k in range(16):     # a cymbal swell as it breaks through the clouds
        s.note(9, 51, c.bt(7) + k * 0.25, 0.25, 12 + k * 3)
    s.note(9, 49, c.bt(8), 4.0, 46)
    s.note(TIMP, 43, c.bt(8), 2.0, 80)
    # The full arrangement plays once: grown to the octave, on to C#, the answer on D.
    tune = [
        "G4:1 A4:.5 B4:.5 D5:1 G5:1", "A5:1.5 B5:.5 C#6:2", "D6:2 B5:1 A5:1", "B5:1.5 A5:.5 G5:2",
        "F#5:1 G5:.5 A5:.5 B5:2", "C#6:1.5 B5:.5 A5:1 C#6:1", "A5:1 G5:.5 F#5:.5 E5:2", "D5:4",
    ]
    c.names(HORN, c.bt(7, 3), "D4:1", vel=72)
    for i, text in enumerate(tune):
        t = c.bt(8 + i)
        c.names(PNO, t, text, vel=80, piano=True)
        c.names(PNO2, t, text, vel=56, piano=True, shift=-12)
        c.names(VLN, t, text, vel=76, legato=0.97)
        c.names(HORN, t, text, vel=70, shift=-12, legato=0.96)
        if i >= 1:
            c.names(FLUTE, t, text, vel=62, shift=0)
    c.pedal(PNO, 8, 16)
    c.pedal(PNO2, 8, 16)
    for bar, t, cd, sym in c.each_chord(8, 16):
        s.chord(CHOIR, c.voicing(sym, 57, 72, 3), t, cd - 0.1, 54)
        s.ramp(CHOIR, 11, 50, 110, t, t + cd * 0.5, 4)
        r, ts, bp, _ = parse_chord(sym)
        s.note(CB, in_range(bp, 28), t, cd - 0.1, 62)
        for k, p in enumerate(c.voicing(sym, 55, 84, 6)):
            s.note(HARP, p, t + k * 0.12, 2.5, 52)
    s.ramp(STR, 11, 118, 50, c.bt(15), c.bt(16, 2), 10)
    s.ramp(VLN, 7, 92, 40, c.bt(15), c.bt(16, 3), 10)
    # ...and drops back to the lone flute, over Era 1's drone, in D.
    c.drone(PAD, c.bt(15), 6 * 4 + 6, vel=58)
    D = 74
    c.deg(PANF, c.bt(17, 1), M.MOTIF, D, vel=70, legato=0.94)
    c.echo(KAL, c.bt(19, 2), M.HEAD, D + 12, vel=46)
    return c, 56.0


def wave():
    c = Cue(84, 3, 24, 404)
    s = c.s
    PANF, PAD, STR, CELLO, KAL, CHOIR = 0, 1, 2, 3, 4, 5
    s.program(PANF, P["pan_flute"], vol=94, pan=60, reverb=78, chorus=10)
    s.program(PAD, P["pad_warm"], vol=76, reverb=72, chorus=30)
    s.program(STR, P["slow_strings"], vol=68, pan=50, reverb=82)
    s.program(CELLO, P["cello"], vol=68, pan=76, reverb=62)
    s.program(KAL, P["kalimba"], vol=80, pan=82, reverb=74)
    s.program(CHOIR, P["oohs"], vol=60, pan=44, reverb=90)
    c.prog(0, "D D G G D D Bm A")
    c.prog(8, "D D G D Bm Bm A A")
    c.prog(16, "F#m D A A D Em D D")
    c.drone(PAD, 0, 72, vel=60, every=24)
    c.strings(STR, 0, 24, 50, 66, 3, vel=46, swell=(70, 116, 86))
    c.roots(CELLO, 0, 24, 38, vel=52)
    D = 74
    # Era 1's flute phrases (A, B, C, D, A grown a third, G), now in D major.
    E1 = {"A": M.MOTIF + [(None, 3)],
          "B": [(4, 1), (3, .5), (2, .5), (1, 1), (2, 1), (0, 2)],
          "C": [(-3, 1), (0, 1.5), (1, .5), (2, 1), (4, 1.5), (5, .5), (4, 1), (2, 1), (1, 1), (2, 3)],
          "D": [(2, 1), (1, .5), (0, .5), (-1, 1), (-3, 3)],
          "G": M.HEAD + [(1, 1), (0, 4)]}
    for bar, beat, ph, shift in ((0, 2, "A", 0), (4, 2, "B", 0), (8, 2, "C", 0), (13, 2, "D", 0),
                                 (16, 2, "A", 2), (20, 2, "G", 0)):
        notes = M.realise(E1[ph], D, "major", shift)
        c.line(PANF, c.bt(bar, beat), notes, vel=74, legato=0.9)
    for bar, beat, ph in ((7, 0, M.TAIL), (19, 0, M.TAIL), (23, 0, M.HEAD), (11, 0, M.HEAD)):
        c.echo(KAL, c.bt(bar, beat), ph, D + 12 if ph is M.TAIL else D, vel=52)
    # The people hum along.
    for bar in range(16, 20, 2):
        sym = c.chords_in(bar)[0][2]
        b0 = c.bt(bar)
        s.chord(CHOIR, c.voicing(sym, 57, 70, 3), b0, 5.8, 46)
        s.ramp(CHOIR, 11, 40, 110, b0, b0 + 3, 6)
        s.ramp(CHOIR, 11, 110, 40, b0 + 3, b0 + 5.8, 6)
    return c, None


def goodbye():
    c = Cue(84, 3, 32, 505)
    s = c.s
    PANF, PAD, STR, CELLO, KAL, CHOIR, FID, HORN, PNO, VLN, HARP, CEL, PNO2 = 0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13
    s.program(9, 0, vol=92, reverb=48)
    s.program(PANF, P["pan_flute"], vol=96, pan=60, reverb=76, chorus=10)
    s.program(PAD, P["pad_warm"], vol=78, reverb=70, chorus=30)
    s.program(STR, P["slow_strings"], vol=72, pan=50, reverb=82)
    s.program(CELLO, P["cello"], vol=70, pan=76, reverb=62)
    s.program(KAL, P["kalimba"], vol=84, pan=82, reverb=74)
    s.program(CHOIR, P["oohs"], vol=62, pan=44, reverb=90)
    s.program(FID, P["fiddle"], vol=84, pan=74, reverb=72)
    s.program(HORN, P["horn"], vol=84, pan=40, reverb=74)
    s.program(PNO, P["piano"], vol=92, pan=56, reverb=72)
    s.program(PNO2, P["piano"], vol=70, pan=48, reverb=72)
    s.program(VLN, P["strings"], vol=76, pan=66, reverb=80)
    s.program(HARP, P["harp"], vol=74, pan=30, reverb=82)
    s.program(CEL, P["celesta"], vol=70, pan=86, reverb=88)
    D = 74
    c.prog(0, "- - - -")
    c.prog(4, "Dm Dm C C Dm Dm G G")          # Era 1's own first progression (i VII i IV)
    c.prog(12, "Dm Dm C C G G A A")           # the lineage, brightening
    c.prog(20, "D D A A G A D D")             # the full motif in D major
    c.prog(28, "D D D D")
    # The light blinks twice: the motif's first step, A then D.
    for t, p in ((0.0, nm("A5")), (2.0, nm("D6"))):
        s.note(KAL, p, t, 3.0, 70)
        s.note(CEL, p + 12, t, 2.5, 46)
    # Era 1's sound: the drone, the low strings, the cello, the heartbeat.
    c.drone(PAD, c.bt(1), 31 * 3, vel=62, every=24)
    s.ramp(PAD, 7, 30, 78, c.bt(1), c.bt(3), 8)
    c.strings(STR, 4, 28, 50, 66, 3, vel=50, swell=(70, 120, 85))
    c.roots(CELLO, 4, 30, 38, vel=56)
    c.heartbeat(2, 31, vel=54)
    # The pan flute plays Era 1's very first phrase, exactly: the call and its answer.
    c.deg(PANF, c.bt(4, 2), M.MOTIF, D, "dorian", vel=74, legato=0.9)
    c.deg(PANF, c.bt(8, 2), [(4, 1), (3, .5), (2, .5), (1, 1), (2, 1), (0, 2)], D, "dorian", vel=72, legato=0.9)
    c.echo(KAL, c.bt(7, 0), M.HEAD, D, "dorian", vel=54)
    # The lineage: generation after generation takes up the motif.
    gens = [(11, FID, 74, "dorian", 72),      # Era 2's fiddle, on D (still dorian: F natural)
            (13, HORN, 60, "major", 70),      # Era 3's horn, on C
            (15, PNO, 67, "lydian", 70),      # Era 4's piano, on G
            (17, VLN, 69, "major", 66)]       # everyone, on A: C#, the turn to major
    for bar, ch, key, scale, vel in gens:
        c.deg(ch, c.bt(bar, 2), M.MOTIF, key, scale, vel=vel, legato=0.95, piano=(ch == PNO))
    c.deg(PANF, c.bt(17, 2), M.MOTIF, 69 + 12, "major", vel=60, legato=0.95)
    c.deg(HORN, c.bt(17, 2), M.MOTIF, 57, "major", vel=56, legato=0.95)
    c.pedal(PNO, 15, 28)
    for bar, t, cd, sym in c.each_chord(12, 20):
        s.chord(CHOIR, c.voicing(sym, 57, 70, 3), t, cd - 0.1, 40 + (bar - 12) * 2)
        s.ramp(CHOIR, 11, 40, 110, t, t + cd * 0.6, 4)
    # Era 1's congas wake gently under the full motif.
    rnd = c.rnd
    for bar in range(20, 28):
        b = c.bt(bar)
        s.note(9, LOW_CONGA, b + 2 + rnd.uniform(-0.01, 0.01), 0.25, 38)
        if bar % 2:
            s.note(9, MUTE_CONGA, b + 1.5, 0.25, 28)
        s.note(9, OPEN_CONGA, b + 1, 0.25, 36)
    # The full motif in D major (Era 1's own fullest phrase), then its answer,
    # slowly, home -- on pan flute, piano, violins and horn together.
    full = M.GROWN + [(6, 1), (4, 1), (5, 1), (4, 3)]
    answer = [(4, 2), (3, 1), (2, 1), (1, 2), (0, 6)]
    for ch, key, vel, kw in ((PANF, D, 82, {}), (PNO, D, 76, {"piano": True}),
                             (VLN, D - 12, 66, {"legato": 0.97}), (HORN, D - 12, 58, {"legato": 0.96})):
        t = c.deg(ch, c.bt(19, 2), full, key, vel=vel, **kw)
        c.deg(ch, c.bt(24), answer, key, vel=vel - 4, **kw)
    for bar, t, cd, sym in c.each_chord(20, 28):
        vo = c.voicing(sym, 50, 66, 3)
        for k, p in enumerate(vo):
            s.note(PNO2, p, t + k * 0.5, cd - k * 0.5, 40)
        for k, p in enumerate(c.voicing(sym, 62, 86, 6)):
            s.note(HARP, p, t + k * 0.1, 2.5, 46)
        s.chord(CHOIR, c.voicing(sym, 57, 72, 3), t, cd - 0.1, 50)
        s.ramp(CHOIR, 11, 50, 112, t, t + cd * 0.5, 4)
    c.pedal(PNO2, 20, 28)
    # Kalimba sparkle, as by Era 1's fire.
    for bar in (20, 21, 23, 26):
        sym = c.chords_in(bar)[0][2]
        vo = c.voicing(sym, 74, 90, 4)
        for k in range(3):
            s.note(KAL, vo[k], c.bt(bar, 1 + k * 0.5), 1.5, 44 - k * 3)
    # The hand lowers: D major held, a harp spread; the light blinks once more.
    c.strings(STR, 28, 30, 50, 69, 4, vel=46, swell=(100, 110, 60))
    s.chord(CHOIR, [62, 66, 69], c.bt(28), 8.8, 40)
    s.ramp(CHOIR, 11, 100, 30, c.bt(28), c.bt(31), 8)
    for k, p in enumerate((50, 57, 62, 66, 69, 74, 78, 81)):
        s.note(HARP, p, c.bt(28) + k * 0.15, 6.0, 42 - k)
    for t, p in ((c.bt(29, 1), nm("A6")), (c.bt(30), nm("D7"))):
        s.note(KAL, p, t, 3.0, 50)
        s.note(CEL, p, t, 2.5, 34)
    s.ramp(PAD, 7, 78, 20, c.bt(29), c.bt(32), 8)
    return c, 73.0


def credits():
    from era2 import A_TUNE as E2_TUNE
    from era3 import A_TUNE as E3_TUNE
    from era4 import A_TUNE as E4_TUNE
    c = Cue(76, 4, 68, 606)
    s = c.s
    PNO, PANF, FID, HORN, WIND, LH, PAD, STR, CELLO, LUTE, KAL, BELLS, CHOIR, HARP, LOW = \
        0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 13, 14, 15
    s.program(9, 0, vol=88, reverb=50)
    s.program(PNO, P["piano"], vol=100, pan=60, reverb=74)
    s.program(PANF, P["pan_flute"], vol=94, pan=60, reverb=78, chorus=10)
    s.program(FID, P["fiddle"], vol=86, pan=70, reverb=72)
    s.program(HORN, P["horn"], vol=90, pan=44, reverb=72)
    s.program(WIND, P["recorder"], vol=74, pan=82, reverb=74)
    s.program(LH, P["piano"], vol=76, pan=48, reverb=74)
    s.program(PAD, P["pad_warm"], vol=74, reverb=78, chorus=36)
    s.program(STR, P["slow_strings"], vol=70, pan=56, reverb=84)
    s.program(CELLO, P["cello"], vol=72, pan=74, reverb=62)
    s.program(LUTE, P["nylon"], vol=76, pan=38, reverb=62)
    s.program(KAL, P["kalimba"], vol=80, pan=84, reverb=78)
    s.program(BELLS, P["bells"], vol=62, pan=66, reverb=92)
    s.program(CHOIR, P["oohs"], vol=62, pan=50, reverb=92)
    s.program(HARP, P["harp"], vol=74, pan=30, reverb=82)
    s.program(LOW, P["contrabass"], vol=64, reverb=50)
    D = 74
    c.prog(0, "D D G/D D")
    c.prog(4, "D Bm G A D/F# G Em7 A")                   # 1 piano alone
    c.prog(12, "D Bm G A D/F# G A D")                    # 2 with strings
    c.prog(20, "Dm Dm C C Dm Dm G G")                    # 3 Era 1: the first night
    c.prog(28, "D G D A Bm G A D")                       # 4 Era 2: the village tune
    c.prog(36, "D G D A Bm Em A7 D")                     # 5 Era 3: the town tune
    c.prog(44, "G A/G Bm Em Cmaj7 G|D/F# Em7 A")         # 6 Era 4: the theme
    c.prog(52, "D A/C# Bm G D/F# G A A")                 # 7 all of them
    c.prog(60, "D D G/D A/D G A D D")                    # 8 the lone flute; the answer
    rnd = c.rnd

    # ---- 0: the hand at rest. Era 1's drone; the kalimba remembers.
    c.drone(PAD, 0, 4 * 4, vel=58)
    c.echo(KAL, c.bt(1), M.HEAD + [(1, 1), (0, 2)], D, vel=56)
    c.heartbeat(0, 4, vel=44)
    # ---- 1-2: the song, piano alone, then with strings and cello.
    song = [
        [(0, 1.5), (1, .5), (2, 1), (4, 1)],             # D
        [(5, 2), (4, 1), (2, 1)],                        # Bm
        [(3, 1.5), (2, .5), (1, 1), (3, 1)],             # G
        [(1, 3), (-3, 1)],                               # A
        [(0, 1.5), (1, .5), (2, 1), (4, 1)],             # D/F#
        [(7, 2), (6, 1), (5, 1)],                        # G
        [(5, 1.5), (4, .5), (2, 1), (1, 1)],             # Em7
        [(1, 2), (None, 1), (-3, 1)],                    # A
    ]
    song2 = song[:5] + [[(7, 2), (8, 1), (9, 1)], [(8, 2), (6, 1), (4, 1)], [(7, 3), (None, 1)]]
    c.deg(PNO, c.bt(3, 3), [(-3, 1)], D, vel=60, piano=True)
    t = c.bt(4)
    for b in song + song2:
        t = c.deg(PNO, t, b, D, vel=64, piano=True)
    c.pedal(PNO, 4, 20)
    c.arp(LH, 4, 20, lo=45, vel=32, shape=(0, 2, 3, 4, 1, 3, 2, 4))
    c.pedal(LH, 4, 20)
    c.pad(PAD, 4, 20, 50, 66, 3, vel=36)
    c.strings(STR, 12, 20, 52, 72, 4, vel=40)
    # The cello's counter-line answers the piano.
    cello = "r:2 F#3:1 A3:1 | D4:2 C#4:1 B3:1 | B3:3 G3:1 | A3:2 E3:2 | F#3:2 A3:1 D4:1 | D4:2 B3:2 | C#4:2 A3:1 E3:1 | D3:4"
    t = c.bt(12)
    for seg in cello.split("|"):
        t = c.names(CELLO, t, seg.strip(), vel=56, legato=0.97)

    # ---- 3: Era 1, the first night. Pan flute in D dorian, kalimba, heartbeat.
    E1C = [(-3, 1), (0, 1.5), (1, .5), (2, 1), (4, 1.5), (5, .5), (4, 1), (2, 1), (1, 1), (2, 3)]
    E1D = [(2, 1), (1, .5), (0, .5), (-1, 1), (-3, 3)]
    c.deg(PANF, c.bt(19, 3), E1C, D, "dorian", vel=72, legato=0.9)
    c.deg(PANF, c.bt(23), E1D, D, "dorian", vel=70, legato=0.9)
    c.deg(PANF, c.bt(24, 3), M.MOTIF, D, "dorian", vel=72, legato=0.9)
    c.echo(KAL, c.bt(26, 1), M.HEAD, D, "dorian", vel=54)
    c.echo(KAL, c.bt(22, 3), M.TAIL, D, "dorian", vel=46)
    c.drone(PAD, c.bt(20), 8 * 4, vel=58, every=16)
    c.strings(STR, 20, 28, 50, 66, 3, vel=42)
    c.roots(CELLO, 20, 28, 38, vel=52)
    c.heartbeat(20, 28, vel=52)
    for bar in range(22, 28):
        b = c.bt(bar)
        s.note(9, LOW_CONGA, b + 2, 0.25, 36 + rnd.randint(-4, 4))
        if bar % 2:
            s.note(9, MUTE_CONGA, b + 1.5, 0.25, 26)

    # ---- 4: Era 2, the village tune on fiddle, recorder second, lute picking.
    c.deg(FID, c.bt(27, 3.5), [(-3, .5)], D, vel=70)
    e2 = M.realise(E2_TUNE, D, "major")
    c.line(FID, c.bt(28), e2, vel=72, legato=0.9)
    sec = [(third_below(p, 2), d) for p, d in e2]
    c.line(WIND, c.bt(30), _from(sec, c.bt(28), c.bt(30)), vel=48, legato=0.9)
    for bar, t, cd, sym in c.each_chord(28, 36):
        r, ts, bp, _ = parse_chord(sym)
        root = in_range(bp, 45)
        pick = [root, root + 7, root + 12, root + (15 if parse_chord(sym)[3] else 16), root + 19,
                root + (15 if parse_chord(sym)[3] else 16), root + 12, root + 7]
        for k in range(int(cd * 2)):
            s.note(LUTE, pick[k % 8], t + k * 0.5 + (0.05 if k % 2 else 0), 0.9, 52 if k % 4 == 0 else 40)
        s.note(9, FRAME, t, 0.25, 50)
        s.note(9, FRAME, t + 2, 0.25, 36)
        s.note(9, 54, t + 1, 0.2, 26)
        s.note(9, 54, t + 3, 0.2, 28)
    c.strings(STR, 28, 36, 52, 70, 3, vel=40)
    c.roots(CELLO, 28, 36, 38, vel=52, split=True)

    # ---- 5: Era 3, the town tune on horn; clarinet beneath, bells, pizzicato.
    s.program(WIND, P["clarinet"], beat=c.bt(36) - 0.02, vol=78, pan=36, reverb=70)
    s.program(LUTE, P["pizz"], beat=c.bt(36) - 0.02, vol=74, pan=76, reverb=60)
    e3 = M.realise(E3_TUNE, 62, "major")
    c.line(HORN, c.bt(36), e3, vel=74, legato=0.92)
    low3 = [(third_below(p, 2), d) for p, d in e3]
    c.line(WIND, c.bt(40), _from(low3, c.bt(36), c.bt(40)), vel=52, legato=0.9)
    for bar, t, cd, sym in c.each_chord(36, 44):
        vo = c.voicing(sym, 55, 69, 3)
        for off in (1, 3):
            s.chord(LUTE, vo, t + off, 0.3, 40 + rnd.randint(-3, 3))
        s.note(9, 37, t + 1, 0.2, 22)
        s.note(9, 37, t + 3, 0.2, 24)
    six = [78, 76, 74, 71, 69, 66]   # D major pentatonic: rounds over the rooftops
    t = c.bt(36)
    for i in range(3):
        for k, p in enumerate(six):
            s.note(BELLS, p, t, 3.0, 36 + (6 if k == 0 else 0) + rnd.randint(-3, 3))
            t += 1.0
        t += 1.0
    s.note(BELLS, 50, c.bt(43), 4.0, 42)
    c.strings(STR, 36, 44, 52, 72, 4, vel=40)
    c.roots(CELLO, 36, 44, 38, vel=54, split=True)

    # ---- 6: Era 4, the theme on piano, warm pads and the gentle pulse.
    s.program(PAD, P["polysynth"], beat=c.bt(43, 3), vol=54, pan=66, reverb=84, chorus=60)
    s.program(LUTE, P["synth_bass2"], beat=c.bt(44) - 0.02, vol=60, reverb=30)
    s.program(WIND, P["celesta"], beat=c.bt(44) - 0.02, vol=62, pan=84, reverb=86)
    e4 = list(E4_TUNE[:-3]) + [(1, 2), (None, 2)]
    c.deg(PNO, c.bt(43, 3), [(-3, 1)], 79, "lydian", vel=58, piano=True)
    c.deg(PNO, c.bt(44), e4, 79, "lydian", vel=64, piano=True)
    c.pedal(PNO, 44, 52)
    c.arp(LH, 44, 52, lo=45, vel=32, shape=(0, 2, 3, 4, 1, 3, 2, 4))
    c.pedal(LH, 44, 52)
    c.pad(PAD, 44, 52, 60, 76, 4, vel=36, bass=False)
    c.strings(STR, 44, 52, 52, 72, 4, vel=42)
    c.roots(CELLO, 44, 52, 38, vel=50)
    for bar, t, cd, sym in c.each_chord(44, 52):
        for k in range(int(cd * 2)):
            s.note(LUTE, in_range(parse_chord(sym)[2], 31), t + k * 0.5, 0.36, 46 if k % 2 == 0 else 36)
        s.note(9, 42, t + 0.5, 0.1, 18)
        s.note(9, 42, t + 1.5, 0.1, 16)
    for bar in (45, 47, 49):
        sym = c.chords_in(bar)[0][2]
        for k, p in enumerate(c.voicing(sym, 81, 96, 3)):
            s.note(WIND, p, c.bt(bar, 2 + k * 0.5), 1.4, 40 - k * 2)

    # ---- 7: all of them together, gently: flute, fiddle, horn and piano.
    tutti = [
        [(0, 1), (1, .5), (2, .5), (4, 1), (7, 1)],      # D      the motif grown
        [(6, 1.5), (5, .5), (4, 2)],                     # A/C#
        [(5, 1.5), (4, .5), (2, 1), (4, 1)],             # Bm
        [(7, 1.5), (6, .5), (5, 1), (4, 1)],             # G
        [(2, 1), (4, 1), (7, 2)],                        # D/F#   the hand opening again
        [(8, 1.5), (7, .5), (5, 2)],                     # G
        [(6, 1.5), (5, .5), (4, 2)],                     # A
        [(4, 3), (None, 1)],                             # A      the question, left open
    ]
    s.program(WIND, P["flute"], beat=c.bt(51), vol=74, pan=84, reverb=78)
    s.program(PAD, P["pad_warm"], beat=c.bt(52) - 0.02, vol=74, reverb=80, chorus=36)
    flat = [n for b in tutti for n in b]
    for ch, key, vel, kw in ((PANF, D, 76, {}), (FID, D, 64, {}), (PNO, D, 70, {"piano": True}),
                             (HORN, D - 12, 62, {"legato": 0.95}), (WIND, D, 42, {})):
        c.deg(ch, c.bt(51, 3), [(-3, 1)], key, vel=vel - 6, **kw)
        c.deg(ch, c.bt(52), flat, key, vel=vel, **kw)
    c.pedal(PNO, 52, 60)
    c.arp(LH, 52, 60, lo=45, vel=36, shape=(0, 2, 3, 4, 1, 3, 2, 4))
    c.pedal(LH, 52, 60)
    c.pad(PAD, 52, 60, 50, 67, 4, vel=44)
    c.strings(STR, 52, 60, 52, 76, 5, vel=50)
    c.roots(CELLO, 52, 60, 38, vel=56, split=True)
    c.roots(LOW, 52, 59, 28, vel=48)
    for bar, t, cd, sym in c.each_chord(52, 59):
        s.chord(CHOIR, c.voicing(sym, 57, 72, 3), t, cd - 0.1, 46)
        s.ramp(CHOIR, 11, 46, 110, t, t + cd * 0.5, 4)
        s.ramp(CHOIR, 11, 110, 70, t + cd * 0.5, t + cd - 0.1, 4)
        for k, p in enumerate(c.voicing(sym, 62, 86, 6)):
            s.note(HARP, p, t + k * 0.12, 2.5, 44)
    t = c.bt(52)
    row = list(six)
    for i in range(4):
        for k, p in enumerate(row):
            s.note(BELLS, p, t, 2.5, 34 + (6 if k == 0 else 0))
            t += 0.5
        t += 0.5
        for k in range(i % 2, len(row) - 1, 2):
            row[k], row[k + 1] = row[k + 1], row[k]
    c.heartbeat(52, 59, vel=50)
    s.note(9, 49, c.bt(52), 3.0, 34)
    for ch in (STR, CHOIR, PAD):
        s.ramp(ch, 7, {STR: 70, CHOIR: 62, PAD: 74}[ch], 30, c.bt(58), c.bt(60), 8)

    # ---- 8: the lone flute over Era 1's drone and heartbeat. The question,
    # a breath of silence, and at last the answer, home.
    for ch, v in ((STR, 70), (CHOIR, 62), (PAD, 66)):
        s.cc(ch, 7, v, c.bt(60))
    c.drone(PAD, c.bt(60), 7.5 * 4, vel=46)
    c.heartbeat(60, 68, vel=40)
    c.deg(PANF, c.bt(60, 1), M.MOTIF, D, vel=70, legato=0.96)
    c.echo(KAL, c.bt(62, 1), M.HEAD, D + 12, vel=46)
    answer = [(4, 2), (3, 1), (2, 1), (1, 4), (0, 4)]
    c.deg(PANF, c.bt(64), answer, D, vel=72, legato=0.97)
    c.deg(PNO, c.bt(64), answer, D - 12, vel=44, piano=True)
    s.cc(PNO, 64, 127, c.bt(64)), s.cc(PNO, 64, 0, c.bt(67, 3))
    c.strings(STR, 64, 67, 50, 69, 4, vel=36, swell=(60, 104, 80))
    c.roots(CELLO, 64, 67, 38, vel=44)
    s.chord(STR, [50, 57, 62, 66, 69], c.bt(66), 7.5, 28)
    s.ramp(STR, 11, 90, 20, c.bt(66, 1), c.bt(68), 10)
    for k, p in enumerate((50, 57, 62, 66, 69, 74, 78, 81)):
        s.note(HARP, p, c.bt(66) + k * 0.18, 8.0, 36 - k)
    for t, p in ((c.bt(66, 2), nm("A6")), (c.bt(67, 0.5), nm("D7"))):
        s.note(KAL, p, t, 3.0, 48)
    s.ramp(PAD, 7, 74, 0, c.bt(66), c.bt(68, 2), 10)
    return c, 68 * 4 * 60 / 76 + 7.3


def _from(notes, t0, t_from):
    """The part of a realised [(pitch, beats)] line that starts at or after t_from."""
    out, t = [], t0
    for p, d in notes:
        if t >= t_from - 1e-6:
            out.append((p, d))
        t += d
    return out


# name: (build, loop, target loudness LUFS). Era 1's full mix sits at -17.2 LUFS and
# its day mix at -21.4; the ending is mild, so most cues sit nearer the day level.
CUES = {
    "last_evening": (last_evening, True, -21.5),
    "countdown": (countdown, True, -20.0),
    "liftoff": (liftoff, False, -18.5),
    "wave": (wave, True, -21.0),
    "goodbye": (goodbye, False, -19.5),
    "credits": (credits, False, -19.0),
}


def cue_length(c):
    return int(round(c.bars * c.bpb * 60 / c.bpm * SR))


def main():
    outdir = out_path("assets", "audio", "music", "ending")
    middir = out_path("tools", "music", "midi", "ending")
    only = sys.argv[1:]
    for name, (fn, loop, target) in CUES.items():
        if only and name not in only:
            continue
        c, secs = fn()
        raw = render_song(c.s, tail_beats=10, keep_mid=os.path.join(middir, name + ".mid"))
        if loop:
            a = seam_loop(raw, cue_length(c))
        else:
            a = fit_oneshot(raw, int(secs * SR), fade_s=2.5)
        g = 10 ** ((target - lufs(a)) / 20)
        g = min(g, 10 ** (-1.0 / 20) / peak(a))
        a = a * g
        write_ogg(os.path.join(outdir, name + ".ogg"), a)
        print(f"  {name}: {len(a) / SR:.2f}s {'loop' if loop else 'one-shot'}, "
              f"{lufs(a):.1f} LUFS (target {target}), peak {dbfs(peak(a)):.2f} dBFS")


if __name__ == "__main__":
    main()
