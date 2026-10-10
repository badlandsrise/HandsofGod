"""Procedural SFX for Hands of God (numpy only). Soft and warm, never harsh.

One-shots are mono (they are often positioned in 3D); rain and wind loops are
stereo. Loops are built circularly (FFT filtering, wrapped events, LFOs with a
whole number of cycles) so they repeat seamlessly at exactly 10 s.
All files are normalised to about -6 dBFS peak.

Run:  python3 tools/music/sfx.py
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from common import out_path, normalise, write_ogg, peak, dbfs  # noqa: E402
from synth import (SR, bell, env_ad, fade, fft_filter, osc, pink, place, reverb,  # noqa: E402
                   svf_bandpass, t_axis, trim_silence)

OUT = out_path("assets", "audio", "sfx")
LOOP_N = 10 * SR
R = np.random.default_rng(2024)


def mtof(m):
    return 440.0 * 2 ** ((m - 69) / 12)


# ------------------------------------------------------------------ hand
def lift():
    """Signature: three warm bell tones rising D5-F#5-A5 with a soft glide shimmer."""
    n = int(1.4 * SR)
    out = np.zeros(n)
    for k, m in enumerate([74, 78, 81]):
        b = bell(mtof(m), 1.3, decay=0.55, bright=0.45, rng=R) * (0.8 + 0.1 * k)
        place(out, b, int(k * 0.065 * SR))
    t = t_axis(1.4)
    glide = mtof(62) * 2 ** (np.clip(t / 0.35, 0, 1) * 7 / 12)  # D4 -> A4 glide underneath
    out += 0.25 * osc(glide) * env_ad(n, 0.05, 0.3)
    out += 0.12 * osc(glide * 2) * env_ad(n, 0.08, 0.25)
    return fade(reverb(out, 1.0, 0.22, R, tone=5000))


def place_sfx():
    n = int(0.5 * SR)
    t = t_axis(0.5)
    f = 55 + 45 * np.exp(-t / 0.03)
    thump = osc(f) * env_ad(n, 0.002, 0.07)
    thump += 0.5 * fft_filter(R.standard_normal(n), hi=500) * env_ad(n, 0.001, 0.02)
    chime = np.zeros(n)
    place(chime, bell(mtof(81), 0.45, decay=0.25, bright=0.3, rng=R) * 0.18, int(0.02 * SR))
    return fade(reverb(thump + chime, 0.6, 0.12, R, tone=3000))


def heavy():
    n = int(0.9 * SR)
    t = t_axis(0.9)
    f = 36 + 40 * np.exp(-t / 0.05)
    x = osc(f) * env_ad(n, 0.003, 0.16)
    x += 0.4 * osc(f * 1.5) * env_ad(n, 0.002, 0.06)
    x += 0.7 * fft_filter(R.standard_normal(n), hi=280) * env_ad(n, 0.002, 0.09)
    # a little settling rumble (gravel)
    x += 0.15 * fft_filter(R.standard_normal(n), lo=150, hi=900) * env_ad(n, 0.04, 0.12)
    return fade(reverb(x, 0.8, 0.12, R, tone=1500))


def scoop():
    n = int(0.55 * SR)
    t = t_axis(0.55)
    u = t / 0.55
    fc = 350 + 1700 * np.sin(np.pi * u) ** 1.5
    x = svf_bandpass(pink(n, R), fc, q=1.4)
    x *= np.sin(np.pi * u) ** 2
    return fade(x)


def too_heavy():
    """Strain creak: stick-slip impulses through woody resonances, plus a low groan."""
    secs = 0.95
    n = int(secs * SR)
    t = t_axis(secs)
    x = np.zeros(n)
    rate = 28 + 30 * np.sin(np.pi * t / secs)  # impulses per second, speeds up then slows
    pos = 0.0
    while True:
        i = int(pos * SR)
        if i >= n:
            break
        place(x, np.array([1.0, -0.6, 0.2]) * R.uniform(0.6, 1.0), i)
        pos += 1.0 / rate[i] * R.uniform(0.8, 1.2)
    creak = np.zeros(n)
    for fc, a in ((420, 1.0), (690, 0.6), (1150, 0.3)):
        creak += a * svf_bandpass(x, fc * (1 + 0.04 * np.sin(2 * np.pi * 3 * t)), q=9)
    creak *= np.sin(np.pi * t / secs) ** 0.7
    groan = osc(70 + 8 * np.sin(np.pi * t / secs)) * 0.25 * np.sin(np.pi * t / secs)
    return fade(fft_filter(creak, hi=2500) + groan)


def gift():
    """Sparkle: a rising shower of tiny pentatonic bells."""
    n = int(1.6 * SR)
    out = np.zeros(n)
    scale = [0, 2, 4, 7, 9]
    for k in range(16):
        deg = k + R.integers(-1, 2)
        m = 81 + 12 * (deg // 5) + scale[deg % 5] - 12
        m = min(m, 105)
        at = int((k * 0.045 + R.uniform(0, 0.02)) * SR)
        b = bell(mtof(m), 0.7, decay=0.22, bright=0.25, rng=R) * (0.5 + 0.5 * R.random()) * (1 - k / 22)
        place(out, b, at)
    shimmer = fft_filter(R.standard_normal(n), lo=5000, hi=9000) * env_ad(n, 0.25, 0.25) * 0.05
    return fade(reverb(out + shimmer, 1.2, 0.3, R, tone=7000))


def ui_click():
    n = int(0.12 * SR)
    x = osc(1050, n) * env_ad(n, 0.001, 0.018)
    x += 0.5 * osc(1575, n) * env_ad(n, 0.001, 0.010)
    x += 0.3 * fft_filter(R.standard_normal(n), lo=800, hi=3000) * env_ad(n, 0.0005, 0.004)
    return fade(x)


def ui_hover():
    n = int(0.12 * SR)
    t = t_axis(0.12)
    x = osc(1400 + 300 * np.clip(t / 0.03, 0, 1), n) * env_ad(n, 0.004, 0.025)
    return fade(x) * 0.6


# ------------------------------------------------------------------ world loops
def fire_loop():
    n = LOOP_N
    base = fft_filter(R.standard_normal(n), lo=60, hi=500, circular=True) * 0.25
    # slow breathing of the flames (whole cycles in 10 s keep it seamless)
    t = np.arange(n) / SR
    breath = 1 + 0.25 * np.sin(2 * np.pi * 0.3 * t) + 0.15 * np.sin(2 * np.pi * 0.7 * t + 1)
    roar = fft_filter(R.standard_normal(n), lo=300, hi=1600, circular=True) * 0.06 * breath
    out = base * breath + roar
    crack = np.zeros(n)
    count = int(10 * 9)
    for _ in range(count):
        L = int(R.uniform(0.002, 0.012) * SR)
        burst = R.standard_normal(L) * np.exp(-np.arange(L) / (L / 4))
        burst = fft_filter(burst, lo=R.uniform(700, 1800), hi=R.uniform(3500, 6000))
        place(crack, burst * R.uniform(0.15, 1.0) ** 2, int(R.uniform(0, n)), wrap=True)
    for _ in range(9):  # deeper pops
        L = int(0.03 * SR)
        pop = R.standard_normal(L) * np.exp(-np.arange(L) / (L / 6))
        place(crack, fft_filter(pop, lo=300, hi=2000) * 1.2, int(R.uniform(0, n)), wrap=True)
    return out + crack * 0.9


def rain_loop():
    n = LOOP_N
    chans = []
    for c in range(2):
        hiss = fft_filter(R.standard_normal(n), lo=600, hi=7000, slope=1.5, circular=True) * 0.2
        body = fft_filter(R.standard_normal(n), lo=150, hi=900, circular=True) * 0.12
        drops = np.zeros(n)
        for _ in range(10 * 70):
            L = int(R.uniform(0.004, 0.02) * SR)
            f = R.uniform(1800, 4500)
            d = np.sin(2 * np.pi * f * np.arange(L) / SR * (1 + np.arange(L) / L * 0.3)) * np.exp(-np.arange(L) / (L / 5))
            place(drops, d * R.uniform(0.02, 0.25), int(R.uniform(0, n)), wrap=True)
        chans.append(hiss + body + fft_filter(drops, hi=6000, circular=True))
    return np.stack(chans, axis=1)


def wind_loop():
    n = LOOP_N
    t = np.arange(n) / SR
    chans = []
    for c in range(2):
        mix = np.zeros(n)
        bands = [(150, 400), (300, 800), (600, 1500), (1100, 2600)]
        for k, (lo, hi) in enumerate(bands):
            b = fft_filter(R.standard_normal(n), lo=lo, hi=hi, slope=2.5, circular=True)
            # gusts: LFOs with whole cycles per 10 s (0.1 Hz multiples)
            lfo = 0.5 + 0.5 * np.sin(2 * np.pi * (0.1 * (k + 1)) * t + R.uniform(0, 6.28) + c)
            lfo2 = 0.6 + 0.4 * np.sin(2 * np.pi * 0.2 * t + k * 1.3 + c * 0.7)
            mix += b * (lfo * lfo2) ** 1.5 * (1.0 / (1 + k * 0.8))
        chans.append(mix)
    return np.stack(chans, axis=1)


# ------------------------------------------------------------------ creatures & work
def wolf_howl():
    secs = 3.2
    n = int(secs * SR)
    t = t_axis(secs)
    # pitch contour: rise, hold with vibrato, long fall
    pts_t = [0, 0.35, 1.1, 2.2, 3.2]
    pts_f = [330, 560, 600, 470, 300]
    f0 = np.interp(t, pts_t, pts_f) * (1 + 0.012 * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - 0.4) * 2, 0, 1))
    tone = sum(osc(f0 * h) / h ** 1.6 for h in range(1, 7))
    # vowel "oo" -> "ow" -> "oo"
    f1 = np.interp(t, [0, 0.5, 2.0, 3.2], [380, 650, 600, 350])
    voiced = svf_bandpass(tone, f1, q=3) + 0.4 * svf_bandpass(tone, f1 * 2.4, q=4)
    breath = svf_bandpass(R.standard_normal(n), f1 * 1.5, q=1.5) * 0.03
    amp = np.interp(t, [0, 0.25, 2.4, 3.2], [0, 1, 0.8, 0])
    x = (voiced + breath) * amp
    x = fft_filter(x, hi=3000)
    return fade(reverb(x, 2.4, 0.45, R, tone=2500))  # distant, in a valley


def work_chop():
    n = int(0.45 * SR)
    t = t_axis(0.45)
    thud = osc(110 + 60 * np.exp(-t / 0.01)) * env_ad(n, 0.001, 0.04)
    crack = fft_filter(R.standard_normal(n), lo=900, hi=3500) * env_ad(n, 0.0005, 0.012) * 0.5
    wood = sum(a * osc(f, n) * env_ad(n, 0.001, d) for f, a, d in ((420, 0.5, 0.06), (760, 0.3, 0.04), (1240, 0.15, 0.025)))
    return fade(reverb(thud + crack + wood, 0.7, 0.18, R, tone=3500))


def work_knap():
    n = int(0.3 * SR)
    tock = sum(a * osc(f, n) * env_ad(n, 0.0005, d) for f, a, d in ((1850, 0.6, 0.02), (2900, 0.35, 0.012), (4100, 0.15, 0.008)))
    click = fft_filter(R.standard_normal(n), lo=1500, hi=5000) * env_ad(n, 0.0003, 0.003) * 0.4
    flake = fft_filter(R.standard_normal(n), lo=3000, hi=7000) * env_ad(n, 0.02, 0.03) * 0.04
    return fade(fft_filter(reverb(tock + click + flake, 0.5, 0.15, R, tone=4000), hi=6000))


def work_dig():
    n = int(0.6 * SR)
    t = t_axis(0.6)
    thud = osc(80 + 40 * np.exp(-t / 0.02)) * env_ad(n, 0.002, 0.05) * 0.8
    grit = np.zeros(n)
    for _ in range(140):
        L = int(R.uniform(0.001, 0.005) * SR)
        g = R.standard_normal(L) * np.exp(-np.arange(L) / (L / 3))
        at = int(abs(R.normal(0.06, 0.09)) * SR)
        place(grit, g * R.uniform(0.1, 0.6), at)
    grit = fft_filter(grit, lo=300, hi=2500)
    soil = fft_filter(R.standard_normal(n), lo=100, hi=900) * env_ad(n, 0.01, 0.12) * 0.4
    return fade(reverb(thud + grit + soil, 0.5, 0.1, R, tone=2000))


SFX = {
    "lift": lift, "place": place_sfx, "heavy": heavy, "scoop": scoop,
    "too_heavy": too_heavy, "gift": gift, "ui_click": ui_click, "ui_hover": ui_hover,
    "fire_loop": fire_loop, "rain_loop": rain_loop, "wind_loop": wind_loop,
    "wolf_howl": wolf_howl, "work_chop": work_chop, "work_knap": work_knap, "work_dig": work_dig,
}
LOOPS = {"fire_loop", "rain_loop", "wind_loop"}


def main():
    for name, fn in SFX.items():
        x = fn()
        if name not in LOOPS:
            x = trim_silence(x)
            x = fade(x, 0.0005, 0.03)
        else:
            assert len(x) == LOOP_N
        x = normalise(x, -6.0)
        write_ogg(os.path.join(OUT, name + ".ogg"), x, q=5)
        print(f"  {name}: {len(x) / SR:.2f}s peak {dbfs(peak(x)):.1f} dBFS")


if __name__ == "__main__":
    main()
