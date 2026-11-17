"""Genererer placeholder-lyde til spillet (hav, vind, måger, knirk, sejl).

Kør fra projektets rod:  python3 tools/generate_audio.py
Kræver numpy. Lydene er syntetiske placeholders og kan erstattes af rigtige optagelser senere.
Loop-filer får et 'smpl'-chunk, så Godot automatisk afspiller dem i loop.
"""
import struct
import wave
from pathlib import Path

import numpy as np

SR = 44100
ROOT = Path(__file__).resolve().parent.parent
AMBIENCE = ROOT / "assets" / "audio" / "ambience"
SFX = ROOT / "assets" / "audio" / "sfx"
rng = np.random.default_rng(42)


def shaped_noise(n, lo, hi, tilt=0.0):
    """Periodisk farvet støj: filtreres i frekvensdomænet, så den looper sømløst."""
    spec = np.fft.rfft(rng.standard_normal(n))
    f = np.fft.rfftfreq(n, 1 / SR)
    gain = np.zeros_like(f)
    band = (f >= lo) & (f <= hi)
    gain[band] = 1.0 / np.maximum(f[band], 1.0) ** tilt
    # bløde kanter på båndet
    gain *= np.clip((f - lo * 0.7) / (lo * 0.3 + 1e-9), 0, 1) * np.clip((hi * 1.3 - f) / (hi * 0.3), 0, 1)
    out = np.fft.irfft(spec * gain, n)
    return out / np.max(np.abs(out))


def periodic_env(t, length, terms):
    """Sum af sinusser, hvis perioder går op i loop-længden."""
    env = np.zeros_like(t)
    for cycles, amp, phase in terms:
        env += amp * np.sin(2 * np.pi * cycles * t / length + phase)
    return env


def write_wav(path, data, loop=False):
    data = np.atleast_2d(data)
    if data.shape[0] < data.shape[1]:
        data = data.T  # (samples, channels)
    data = np.clip(data, -1, 1)
    pcm = (data * 32767).astype("<i2")
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(pcm.shape[1])
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    if loop:
        _add_loop_chunk(path, pcm.shape[0])
    print(f"  {path.relative_to(ROOT)}  ({pcm.shape[0] / SR:.1f}s{', loop' if loop else ''})")


def _add_loop_chunk(path, frames):
    smpl = struct.pack("<9I", 0, 0, int(1e9 / SR), 60, 0, 0, 0, 1, 0)
    smpl += struct.pack("<6I", 0, 0, 0, frames - 1, 0, 0)
    chunk = b"smpl" + struct.pack("<I", len(smpl)) + smpl
    raw = path.read_bytes() + chunk
    raw = raw[:4] + struct.pack("<I", len(raw) - 8) + raw[8:]
    path.write_bytes(raw)


def fade(n, attack, release):
    env = np.ones(n)
    a, r = int(attack * SR), int(release * SR)
    if a:
        env[:a] = np.linspace(0, 1, a)
    if r:
        env[-r:] *= np.linspace(1, 0, r) ** 2
    return env


def ocean(length=24.0):
    n = int(length * SR)
    t = np.arange(n) / SR
    channels = []
    for ch in range(2):
        swell = 0.55 + periodic_env(t, length, [(4, 0.25, ch * 0.7), (3, 0.18, 1.3 + ch), (7, 0.07, 2.1)])
        swell = np.clip(swell, 0.15, 1.0)
        rumble = shaped_noise(n, 30, 500, tilt=1.0)
        wash = shaped_noise(n, 600, 7000, tilt=0.5)
        sig = rumble * (0.35 + 0.65 * swell) + wash * 0.45 * swell ** 3
        channels.append(sig)
    out = np.array(channels)
    return out / np.max(np.abs(out)) * 0.7


def wind(length=12.0):
    n = int(length * SR)
    t = np.arange(n) / SR
    channels = []
    for ch in range(2):
        gust = 0.6 + periodic_env(t, length, [(2, 0.25, ch), (5, 0.12, 0.5 + ch)])
        channels.append(shaped_noise(n, 250, 2500, tilt=0.8) * np.clip(gust, 0.2, 1))
    out = np.array(channels)
    return out / np.max(np.abs(out)) * 0.6


def gull(calls, base):
    parts = []
    for i in range(calls):
        d = rng.uniform(0.22, 0.34)
        n = int(d * SR)
        t = np.arange(n) / SR
        x = t / d
        f = base * (1.0 + 0.45 * np.sin(np.pi * np.clip(x * 1.6, 0, 1)) - 0.25 * x)
        f *= 1 + 0.01 * np.sin(2 * np.pi * 28 * t)
        phase = 2 * np.pi * np.cumsum(f) / SR
        tone = sum(a * np.sin(k * phase) for k, a in [(1, 1.0), (2, 0.55), (3, 0.35), (4, 0.2)])
        rasp = 1 + 0.35 * np.sin(2 * np.pi * 45 * t)
        env = np.sin(np.pi * x) ** 0.6
        parts.append(tone * rasp * env + 0.03 * rng.standard_normal(n) * env)
        parts.append(np.zeros(int(rng.uniform(0.05, 0.14) * SR)))
    out = np.concatenate(parts)
    return out / np.max(np.abs(out)) * 0.5


def creak(d=0.9):
    n = int(d * SR)
    out = np.zeros(n)
    pos, rate = 0.0, rng.uniform(55, 75)
    k = np.arange(int(0.012 * SR)) / SR
    grain = np.exp(-k * 400) * (np.sin(2 * np.pi * 520 * k) + 0.6 * np.sin(2 * np.pi * 1150 * k))
    while pos < d - 0.02:
        i = int(pos * SR)
        seg = grain[: n - i]
        out[i:i + len(seg)] += seg * rng.uniform(0.6, 1.0)
        rate *= rng.uniform(0.99, 1.025)
        pos += 1 / rate * rng.uniform(0.85, 1.15)
    out *= np.sin(np.pi * np.arange(n) / n) ** 0.8
    return out / np.max(np.abs(out)) * 0.5


def sail_flap(d=0.55):
    n = int(d * SR)
    t = np.arange(n) / SR
    noise = shaped_noise(n, 80, 3000, tilt=0.7)
    flutter = 0.5 + 0.5 * np.abs(np.sin(2 * np.pi * 9 * t * (1 - 0.5 * t / d)))
    out = noise * flutter * fade(n, 0.01, 0.35)
    return out / np.max(np.abs(out)) * 0.6


if __name__ == "__main__":
    print("Genererer lyde:")
    write_wav(AMBIENCE / "ocean_loop.wav", ocean(), loop=True)
    write_wav(AMBIENCE / "wind_loop.wav", wind(), loop=True)
    for i, (calls, base) in enumerate([(3, 1250), (2, 1400), (4, 1150)], start=1):
        write_wav(SFX / f"gull_{i}.wav", gull(calls, base))
    write_wav(SFX / "creak.wav", creak())
    write_wav(SFX / "sail_flap.wav", sail_flap())
