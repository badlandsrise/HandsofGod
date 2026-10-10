"""Shared helpers for the Hands of God music and SFX build.

MIDI writing (mido), rendering (fluidsynth -> raw float32), loop seaming,
loudness normalisation and OGG Vorbis encoding (ffmpeg).
"""
import os
import subprocess
import tempfile

import mido
import numpy as np

SR = 44100
SF2 = "/usr/share/sounds/sf2/FluidR3_GM.sf2"
TPB = 480  # MIDI ticks per beat
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

# General MIDI programs (0-based)
GM = dict(
    piano=0, music_box=10, vibes=11, marimba=12, glock=9, bells=14,
    nylon=24, bass=32, harp=46, timpani=47, strings=48, slow_strings=49,
    choir=52, oohs=53, cello=42, contrabass=43, horn=60, oboe=68,
    clarinet=71, flute=73, recorder=74, pan_flute=75, ocarina=79,
    pad_new_age=88, pad_warm=89, pad_choir=91, pad_halo=94,
    kalimba=108, tinkle=112, taiko=116, melodic_tom=117,
    celesta=8, accordion=21, steel=25, violin=40, viola=41, tremolo=44, pizz=45,
    bassoon=70, fiddle=110,
    harpsichord=6, trumpet=56, trombone=57, tuba=58, brass=61, piccolo=72,
)


class Song:
    """Collects notes on channels, writes a single-track MIDI file."""

    def __init__(self, bpm, beats_per_bar=3):
        self.bpm = bpm
        self.bpb = beats_per_bar
        self.events = []  # (tick, order, msg)
        self.end_beat = 0.0

    @staticmethod
    def tick(beat):
        return int(round(beat * TPB))

    def program(self, ch, prog, beat=0.0, vol=100, pan=64, reverb=40, chorus=0):
        t = self.tick(beat)
        for c, v in ((7, vol), (10, pan), (91, reverb), (93, chorus), (11, 127)):
            self.events.append((t, 0, mido.Message("control_change", channel=ch, control=c, value=v)))
        if ch != 9:
            self.events.append((t, 0, mido.Message("program_change", channel=ch, program=prog)))

    def cc(self, ch, control, value, beat):
        self.events.append((max(0, self.tick(beat)), 1,
                            mido.Message("control_change", channel=ch, control=control,
                                         value=int(max(0, min(127, value))))))

    def ramp(self, ch, control, v0, v1, b0, b1, steps=24):
        for i in range(steps + 1):
            f = i / steps
            self.cc(ch, control, v0 + (v1 - v0) * f, b0 + (b1 - b0) * f)

    def note(self, ch, pitch, beat, dur, vel=80):
        if pitch is None:
            return
        pitch = int(pitch)
        vel = int(max(1, min(127, vel)))
        t0 = max(0, self.tick(beat))
        t1 = max(t0 + 1, self.tick(beat + dur))
        self.events.append((t0, 3, mido.Message("note_on", channel=ch, note=pitch, velocity=vel)))
        self.events.append((t1, 2, mido.Message("note_off", channel=ch, note=pitch, velocity=0)))
        self.end_beat = max(self.end_beat, beat + dur)

    def chord(self, ch, pitches, beat, dur, vel=70):
        for p in pitches:
            self.note(ch, p, beat, dur, vel)

    def save(self, path, tail_beats=8):
        mid = mido.MidiFile(ticks_per_beat=TPB)
        tr = mido.MidiTrack()
        mid.tracks.append(tr)
        tr.append(mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(self.bpm), time=0))
        tr.append(mido.MetaMessage("time_signature", numerator=self.bpb, denominator=4, time=0))
        evs = sorted(self.events, key=lambda e: (e[0], e[1]))
        end = self.tick(self.end_beat + tail_beats)
        # A silent controller at the end keeps fluidsynth rendering the reverb tail.
        evs.append((end, 9, mido.Message("control_change", channel=15, control=7, value=0)))
        last = 0
        for t, _, m in evs:
            tr.append(m.copy(time=t - last))
            last = t
        tr.append(mido.MetaMessage("end_of_track", time=0))
        mid.save(path)


def render_midi(mid_path, gain=0.35):
    """Render a MIDI file with fluidsynth; returns float64 array (n, 2)."""
    fd, raw = tempfile.mkstemp(suffix=".raw")
    os.close(fd)
    subprocess.run(["fluidsynth", "-ni", "-q", "-g", str(gain), "-r", str(SR),
                    "-T", "raw", "-O", "float", "-F", raw, SF2, mid_path],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    a = np.fromfile(raw, dtype=np.float32).reshape(-1, 2).astype(np.float64)
    os.unlink(raw)
    return a


def render_song(song, tail_beats=8, gain=0.35, keep_mid=None):
    fd, mp = tempfile.mkstemp(suffix=".mid")
    os.close(fd)
    song.save(mp, tail_beats)
    a = render_midi(mp, gain)
    if keep_mid:
        os.makedirs(os.path.dirname(keep_mid), exist_ok=True)
        os.replace(mp, keep_mid)
    else:
        os.unlink(mp)
    return a


def seam_loop(audio, n, xfade=1024):
    """Make `audio` loop seamlessly at exactly n samples.

    Everything rendered past n (note releases and reverb tails) is wrapped
    around and mixed into the head, so the end flows into the start exactly
    as it would if the piece kept playing. A very short equal-power crossfade
    from the tail into the head then smooths the seam sample-exactly.
    """
    out = np.zeros((n, 2))
    m = min(len(audio), n)
    out[:m] = audio[:m]
    tail = audio[n:]
    for i in range(0, len(tail), n):
        seg = tail[i:i + n]
        out[:len(seg)] += seg
    if xfade:
        # Ease the last samples so the slope into sample 0 is continuous:
        # predicted next sample vs the real head, corrected with a smooth ramp.
        pred = 2 * out[n - 1] - out[n - 2]
        delta = out[0] - pred
        r = (0.5 - 0.5 * np.cos(np.linspace(0, np.pi, xfade)))[:, None]
        out[n - xfade:] += delta * r
    return out


def fit_oneshot(audio, n, fade_s=0.6):
    """Trim/pad to n samples with a gentle fade-out at the end."""
    out = np.zeros((n, 2))
    m = min(len(audio), n)
    out[:m] = audio[:m]
    k = min(int(fade_s * SR), n)
    out[n - k:] *= (np.cos(np.linspace(0, np.pi / 2, k)) ** 2)[:, None]
    return out


def dbfs(x):
    return 20 * np.log10(max(float(x), 1e-12))


def peak(a):
    return float(np.max(np.abs(a)))


def normalise(a, target_dbfs):
    p = peak(a)
    return a * (10 ** (target_dbfs / 20) / p) if p > 0 else a


def write_ogg(path, audio, q=5, mono=False):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    a = np.asarray(audio, dtype=np.float32)
    if a.ndim == 1:
        a = a[:, None]
    if mono and a.shape[1] == 2:
        a = a.mean(axis=1, keepdims=True)
    assert np.max(np.abs(a)) <= 1.0, f"clipping in {path}"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "f32le", "-ar", str(SR),
                    "-ac", str(a.shape[1]), "-i", "-", "-c:a", "libvorbis", "-q:a", str(q),
                    path], input=np.ascontiguousarray(a).tobytes(), check=True)


def write_mp3(path, audio, q=4):
    a = np.ascontiguousarray(np.asarray(audio, dtype=np.float32))
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "f32le", "-ar", str(SR),
                    "-ac", "2", "-i", "-", "-c:a", "libmp3lame", "-q:a", str(q), path],
                   input=a.tobytes(), check=True)


def read_audio(path):
    r = subprocess.run(["ffmpeg", "-loglevel", "error", "-i", path, "-f", "f32le",
                        "-ac", "2", "-ar", str(SR), "-"], capture_output=True, check=True)
    return np.frombuffer(r.stdout, dtype=np.float32).reshape(-1, 2).astype(np.float64)


def out_path(*parts):
    return os.path.join(ROOT, *parts)


def lufs(audio):
    """Integrated loudness (EBU R128, LUFS) of a stereo float array, via ffmpeg."""
    a = np.ascontiguousarray(np.asarray(audio, dtype=np.float32))
    r = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-f", "f32le", "-ar", str(SR), "-ac", "2",
                        "-i", "-", "-af", "ebur128", "-f", "null", "-"],
                       input=a.tobytes(), capture_output=True, check=True)
    lines = [ln.strip() for ln in r.stderr.decode().splitlines() if ln.strip().startswith("I:")]
    return float(lines[-1].split()[1])
