"""Small numpy synthesis toolkit for the procedural SFX and voices."""
import numpy as np

SR = 44100


def t_axis(secs):
    return np.arange(int(secs * SR)) / SR


def env_ad(n, attack, decay_tau, sustain_secs=0.0):
    """Attack (s) then exponential decay with time constant decay_tau (s)."""
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-5), 0, 1)
    a = np.sin(a * np.pi / 2) ** 2
    d = np.exp(-np.clip(t - attack - sustain_secs, 0, None) / decay_tau)
    return a * d


def fade(x, fin=0.002, fout=0.01):
    x = x.copy()
    i, o = int(fin * SR), int(fout * SR)
    if i:
        x[:i] *= np.linspace(0, 1, i)
    if o:
        x[-o:] *= np.linspace(1, 0, o) ** 2
    return x


def osc(freq, n=None, phase=0.0):
    """Sine with per-sample frequency (array) or constant."""
    if np.isscalar(freq):
        freq = np.full(n, float(freq))
    ph = 2 * np.pi * np.cumsum(freq) / SR + phase
    return np.sin(ph)


def bell(freq, secs, decay=0.6, bright=0.5, rng=None):
    """Warm bell/chime: a few slightly inharmonic partials with shorter upper decays."""
    n = int(secs * SR)
    partials = [(1.0, 1.0, 1.0), (2.0, 0.35 * bright, 0.55), (3.01, 0.18 * bright, 0.35),
                (4.2, 0.08 * bright, 0.22), (0.5, 0.12, 1.3)]
    out = np.zeros(n)
    for ratio, amp, dk in partials:
        f = freq * ratio
        if f > 16000:
            continue
        out += amp * osc(f, n, rng.uniform(0, 6.28) if rng is not None else 0) * env_ad(n, 0.003, decay * dk)
    return out


def fft_filter(x, lo=None, hi=None, slope=2.0, circular=False, gain_fn=None):
    """Zero-phase band filter via FFT (smooth Butterworth-like magnitude).

    circular=True keeps the signal periodic (for seamless loops); otherwise it
    zero-pads to avoid wrap-around.
    """
    n = len(x)
    m = n if circular else int(2 ** np.ceil(np.log2(n * 2)))
    X = np.fft.rfft(x, m)
    f = np.fft.rfftfreq(m, 1 / SR)
    g = np.ones_like(f)
    if lo:
        g *= 1 / np.sqrt(1 + (lo / np.maximum(f, 1e-3)) ** (2 * slope))
    if hi:
        g *= 1 / np.sqrt(1 + (f / hi) ** (2 * slope))
    if gain_fn is not None:
        g *= gain_fn(f)
    return np.fft.irfft(X * g, m)[:n]


def pink(n, rng):
    X = np.fft.rfft(rng.standard_normal(n))
    f = np.fft.rfftfreq(n, 1 / SR)
    X /= np.sqrt(np.maximum(f, 20.0))
    y = np.fft.irfft(X, n)
    return y / np.max(np.abs(y))


def svf_bandpass(x, fc, q=2.0):
    """Time-varying state-variable band-pass. fc may be an array (Hz)."""
    n = len(x)
    fc = np.broadcast_to(np.asarray(fc, dtype=float), (n,))
    f = 2 * np.sin(np.pi * np.clip(fc, 20, SR / 6) / SR)
    damp = 1.0 / q
    low = band = 0.0
    out = np.empty(n)
    for i in range(n):
        high = x[i] - low - damp * band
        band += f[i] * high
        low += f[i] * band
        out[i] = band
    return out


def reverb(x, secs=1.2, mix=0.25, rng=None, tone=4000, circular=False):
    """Soft synthetic room: convolve with decaying, low-passed noise."""
    rng = rng or np.random.default_rng(1)
    n_ir = int(secs * SR)
    ir = rng.standard_normal(n_ir) * np.exp(-np.arange(n_ir) / SR / (secs / 6.9))
    ir = fft_filter(ir, hi=tone)
    ir[: int(0.012 * SR)] *= np.linspace(0, 1, int(0.012 * SR))
    ir /= np.sqrt(np.sum(ir ** 2))
    if circular:
        L = len(x)
        irp = np.zeros(L)
        irp[:min(L, n_ir)] = ir[:L]
        wet = np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(irp), L)
        return x * (1 - mix) + wet * mix * 3
    m = int(2 ** np.ceil(np.log2(len(x) + n_ir)))
    wet = np.fft.irfft(np.fft.rfft(x, m) * np.fft.rfft(ir, m), m)[: len(x) + n_ir]
    dry = np.concatenate([x, np.zeros(n_ir)])
    return dry * (1 - mix) + wet * mix * 3


def place(dst, src, at, wrap=False):
    """Mix src into dst at sample offset `at` (optionally wrapping around)."""
    n = len(dst)
    if wrap:
        idx = (np.arange(len(src)) + at) % n
        np.add.at(dst, idx, src)
    else:
        end = min(n, at + len(src))
        if end > at:
            dst[at:end] += src[: end - at]
    return dst


def trim_silence(x, rel_db=-50.0, pad=0.02):
    """Cut the tail once it falls below rel_db under the peak."""
    thresh = np.max(np.abs(x)) * 10 ** (rel_db / 20)
    idx = np.where(np.abs(x) > thresh)[0]
    if len(idx) == 0:
        return x
    end = min(len(x), idx[-1] + int(pad * SR))
    return x[:end]
