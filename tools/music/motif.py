"""The hand motif: the five-note theme every era's music grows from.

Written as data so each era's piece (and the stingers and title) reuses it.

Shape: a pickup from the fifth below, a rise to home, two steps up, and an
open leap to the fifth above -- "a hand opening". In D it is A-D-E-F(#)-A.
It reads as a question (it ends on the fifth, not home); its answer falls
back down the same steps.

Pitches are scale degrees (0 = tonic, 7 = octave; negatives go down) so the
same motif works in Era 1's dorian, the title's major, and later modes.
Durations are in beats (quarter notes).
"""

# (degree, beats)
MOTIF = [(-3, 1.0), (0, 1.5), (1, 0.5), (2, 1.0), (4, 2.0)]

# The answer: the motif mirrored, falling back home.
ANSWER = [(4, 1.0), (3, 0.5), (2, 0.5), (1, 1.0), (0, 3.0)]

# Fragments for call-and-response and colour echoes.
HEAD = MOTIF[:3]                              # A - D - E
TAIL = [(1, 0.5), (2, 0.5), (4, 2.0)]         # E - F - A (the "opening")
# The motif "grown": the leap goes on up to the octave (used for climaxes).
GROWN = [(-3, 1.0), (0, 1.0), (1, 0.5), (2, 0.5), (4, 1.0), (7, 2.0)]

# Scales as semitone offsets from the tonic.
SCALES = {
    "dorian": [0, 2, 3, 5, 7, 9, 10],
    "aeolian": [0, 2, 3, 5, 7, 8, 10],
    "major": [0, 2, 4, 5, 7, 9, 11],
    "lydian": [0, 2, 4, 6, 7, 9, 11],
    "mixolydian": [0, 2, 4, 5, 7, 9, 10],
    "penta_minor": [0, 3, 5, 7, 10],
}

# How the motif grows across eras (section 13.1). Era pieces read this.
ERAS = {
    1: dict(key=62, scale="dorian", lead="pan_flute", note="lone flute, hand drum, drone"),
    2: dict(key=62, scale="mixolydian", lead="strings", note="strings and lute join"),
    3: dict(key=65, scale="major", lead="horn", note="small orchestra and church bells"),
    4: dict(key=67, scale="lydian", lead="piano", note="piano and soft synth pads"),
}


def pitch(degree, key=62, scale="dorian"):
    """MIDI pitch of a scale degree relative to `key` (MIDI tonic)."""
    sc = SCALES[scale]
    octave, idx = divmod(degree, len(sc))
    return key + 12 * octave + sc[idx]


def realise(phrase, key=62, scale="dorian", shift=0):
    """Turn [(degree, beats)] into [(midi_pitch or None, beats)].

    `shift` moves the phrase up/down by scale steps. A degree of None is a rest.
    """
    out = []
    for d, b in phrase:
        out.append((None if d is None else pitch(d + shift, key, scale), b))
    return out


def length(phrase):
    return sum(b for _, b in phrase)
