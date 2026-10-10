"""Villager gibberish voices (section 13.3), formant-synthesised with numpy.

Output (mono OGG, -6 dBFS peak) in assets/audio/sfx/voice/:
  syl_00.ogg .. syl_39.ogg   8 consonant onsets x 5 vowels, neutral pitch
                             (consonant/vowel table printed and listed in
                             syllables.txt so code can pick by sound)
  hum_happy_0/1.ogg          bright chirp, up then down
  hum_question_0/1.ogg       rising at the end
  hum_worry_0/1.ogg          wavering, falling, a little tremolo
  hum_cheer_0/1.ogg          high and open, rising, long last vowel
  hum_sad_0/1.ogg            closed-mouth hum, slow and falling

Base pitch is about 240 Hz (a small person); the game shifts pitch per person
(age + seed) with pitch_scale, so keep these neutral.

Run:  python3 tools/music/voices.py
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from common import normalise, out_path, write_ogg  # noqa: E402
from synth import SR, fade, fft_filter, svf_bandpass  # noqa: E402

OUT = out_path("assets", "audio", "sfx", "voice")
R = np.random.default_rng(77)
F0 = 240.0
SIZE = 1.12  # formant scale: small, round, friendly voices

VOWELS = {  # F1, F2, F3 (Hz) and bandwidths
    "a": ((780, 1250, 2550), (110, 120, 160)),
    "e": ((480, 1900, 2600), (80, 110, 160)),
    "i": ((310, 2250, 3000), (60, 110, 180)),
    "o": ((500, 880, 2500), (80, 90, 150)),
    "u": ((340, 780, 2300), (60, 90, 150)),
}
CONSONANTS = ["m", "n", "b", "d", "l", "w", "k", "h"]


def harmonic_voice(f0, F, B, amp, nasal=None, breath=0.04):
    """Additive glottal source shaped by time-varying formants.

    f0, amp: arrays (n,). F, B: arrays (n, 3). nasal: optional (n,) 0..1 that
    adds a low murmur formant and damps the upper ones (for m/n/hums).
    """
    n = len(f0)
    out = np.zeros(n)
    jitter = 1 + 0.004 * np.cumsum(R.standard_normal(n)) / np.sqrt(np.arange(1, n + 1))
    f0 = f0 * jitter
    phase = 2 * np.pi * np.cumsum(f0) / SR
    H = int(5200 / f0.min())
    for h in range(1, H + 1):
        fh = h * f0
        g = np.zeros(n)
        for k in range(3):
            g += (1.0, 0.6, 0.25)[k] / np.sqrt(1 + ((fh - F[:, k]) / (B[:, k] / 2)) ** 2)
        if nasal is not None:
            murmur = 1.0 / np.sqrt(1 + ((fh - 260) / 60) ** 2)
            g = g * (1 - 0.85 * nasal) + murmur * nasal
        tilt = 1.0 / h ** 0.9
        out += np.sin(h * phase + h * 0.3) * g * tilt * (fh < 9000)
    # a little breath, shaped by F2
    br = svf_bandpass(R.standard_normal(n), F[:, 1], q=2.5) * breath
    return (out + br) * amp


def noise_through(n, fcs, q=4.0, gains=(1.0, 0.6, 0.3)):
    x = R.standard_normal(n)
    return sum(g * svf_bandpass(x, fc, q) for fc, g in zip(fcs, gains))


def syllable(cons, vowel, dur=0.22, f0_start=F0, f0_end=F0 * 0.93, gain=1.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    Fv = np.array(VOWELS[vowel][0], float) * SIZE
    Bv = np.array(VOWELS[vowel][1], float)
    F = np.tile(Fv, (n, 1))
    B = np.tile(Bv, (n, 1))
    amp = np.ones(n)
    nasal = None
    pre = np.zeros(0)   # unvoiced onset placed before the voiced part
    trans = int(0.045 * SR)

    def glide(start_F, length):
        L = min(length, n)
        w = (0.5 - 0.5 * np.cos(np.linspace(0, np.pi, L)))[:, None]
        F[:L] = np.array(start_F, float)[None, :] * SIZE * (1 - w) + Fv[None, :] * w

    if cons in ("m", "n"):
        m_len = int(0.07 * SR)
        nasal = np.zeros(n)
        nasal[:m_len] = 1.0
        nasal[m_len:m_len + trans] = np.linspace(1, 0, min(trans, n - m_len))
        glide((300, 1000 if cons == "m" else 1700, 2400), m_len + trans)
        amp[:m_len + trans] = 0.55 + 0.45 * np.clip(np.arange(m_len + trans) - m_len, 0, None)[:n] / trans
    elif cons in ("b", "d"):
        glide((350, 900 if cons == "b" else 1800, 2400), trans)
        L = int(0.01 * SR)
        burst = R.standard_normal(L) * np.exp(-np.arange(L) / (L / 3))
        burst = fft_filter(burst, hi=1500) if cons == "b" else fft_filter(burst, lo=2200, hi=4500)
        pre = burst * 0.25
    elif cons == "k":
        glide((400, 2100, 2700), trans)
        L = int(0.012 * SR)
        burst = fft_filter(R.standard_normal(L) * np.exp(-np.arange(L) / (L / 3)), lo=1400, hi=3200) * 0.35
        A = int(0.035 * SR)
        asp = noise_through(A, [np.full(A, f) for f in Fv]) * np.linspace(0.18, 0.05, A)
        pre = np.concatenate([burst, asp])
    elif cons == "l":
        glide((360, 1100, 2800), int(0.06 * SR) + trans)
        L = int(0.05 * SR)
        amp[:L + trans] = 0.7 + 0.3 * np.clip(np.arange(L + trans) - L, 0, None) / trans
    elif cons == "w":
        glide((300, 650, 2200), int(0.09 * SR))
    elif cons == "h":
        A = int(0.06 * SR)
        asp = noise_through(A, [np.full(A, f) for f in Fv])
        asp *= np.sin(np.linspace(0, np.pi / 2, A)) * 0.12
        pre = asp
    # Vowel envelope: quick rise, gentle end.
    a_len = int(0.012 * SR)
    amp[:a_len] *= np.linspace(0, 1, a_len)
    rel = int(0.07 * SR)
    amp[-rel:] *= np.cos(np.linspace(0, np.pi / 2, rel)) ** 2
    f0 = np.geomspace(f0_start, f0_end, n) if np.isscalar(f0_start) else f0_start
    voiced = harmonic_voice(f0, F, B, amp, nasal)
    out = np.concatenate([pre, voiced]) if len(pre) else voiced
    return out * gain


def hum(dur, f0_curve, vowel="u", nasal_amount=1.0, trem=0.0):
    """Closed (nasal) or open hum with an explicit pitch curve."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    f0 = np.interp(t, np.linspace(0, dur, len(f0_curve)), f0_curve)
    if trem:
        f0 = f0 * (1 + trem * np.sin(2 * np.pi * 6.0 * t))
    Fv = np.array(VOWELS[vowel][0], float) * SIZE
    Bv = np.array(VOWELS[vowel][1], float)
    amp = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 0.6
    return harmonic_voice(f0, np.tile(Fv, (n, 1)), np.tile(Bv, (n, 1)), amp, np.full(n, nasal_amount))


def phrase(parts, gap=0.02):
    """parts: list of audio arrays; joined with small overlaps/gaps."""
    out = []
    for p in parts:
        out.append(p)
        out.append(np.zeros(int(gap * SR)))
    return np.concatenate(out)


def contour_syl(c, v, dur, a, b, gain=1.0):
    return syllable(c, v, dur, a, b, gain)


def build_hums():
    f = F0
    hums = {
        "happy_0": phrase([contour_syl("b", "a", 0.16, f * 1.15, f * 1.35), contour_syl("d", "i", 0.24, f * 1.45, f * 1.1)], 0.01),
        "happy_1": phrase([contour_syl("l", "e", 0.15, f * 1.2, f * 1.4), contour_syl("l", "o", 0.14, f * 1.35, f * 1.3),
                           contour_syl("m", "i", 0.22, f * 1.5, f * 1.2)], 0.0),
        "question_0": phrase([contour_syl("n", "a", 0.18, f, f * 0.95), contour_syl("w", "i", 0.30, f * 0.98, f * 1.45)], 0.02),
        "question_1": phrase([hum(0.22, [f, f * 0.95]), hum(0.32, [f * 0.95, f * 1.05, f * 1.5])], 0.06),
        "worry_0": phrase([contour_syl("h", "o", 0.26, f * 1.05, f * 0.95), contour_syl("", "o", 0.38, f, f * 0.8)], 0.05),
        "worry_1": hum(0.8, [f * 1.05, f * 0.98, f * 1.02, f * 0.9, f * 0.82], vowel="o", nasal_amount=0.6, trem=0.025),
        "cheer_0": phrase([contour_syl("w", "a", 0.16, f * 1.3, f * 1.4), contour_syl("h", "e", 0.42, f * 1.6, f * 1.75, 1.1)], 0.0),
        "cheer_1": phrase([contour_syl("", "e", 0.12, f * 1.4, f * 1.5), contour_syl("l", "a", 0.12, f * 1.5, f * 1.55),
                           contour_syl("h", "a", 0.45, f * 1.7, f * 1.8, 1.1)], 0.0),
        "sad_0": hum(1.1, [f * 0.95, f * 0.9, f * 0.82, f * 0.72], vowel="u"),
        "sad_1": phrase([hum(0.45, [f * 0.9, f * 0.86]), hum(0.7, [f * 0.85, f * 0.78, f * 0.7])], 0.08),
    }
    return hums


def main():
    os.makedirs(OUT, exist_ok=True)
    table = []
    i = 0
    for c in CONSONANTS:
        for v in "aeiou":
            dur = 0.19 + 0.05 * R.random()
            x = syllable(c, v, dur, F0 * (1 + 0.03 * R.standard_normal()), F0 * 0.92)
            x = fade(x, 0.001, 0.02)
            write_ogg(os.path.join(OUT, f"syl_{i:02d}.ogg"), normalise(x, -6.0))
            table.append(f"syl_{i:02d}\t{c}{v}\t{len(x) / SR:.2f}s")
            i += 1
    for name, x in build_hums().items():
        x = fade(x, 0.002, 0.03)
        write_ogg(os.path.join(OUT, f"hum_{name}.ogg"), normalise(x, -6.0))
        table.append(f"hum_{name}\t\t{len(x) / SR:.2f}s")
    with open(os.path.join(OUT, "syllables.txt"), "w") as fh:
        fh.write("# file\tsound\tlength (generated by tools/music/voices.py)\n" + "\n".join(table) + "\n")
    print(f"  {i} syllables + {len(table) - i} hums")


if __name__ == "__main__":
    main()
