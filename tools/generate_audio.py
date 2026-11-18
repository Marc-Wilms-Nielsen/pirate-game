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


def splash(d=0.7):
    n = int(d * SR)
    t = np.arange(n) / SR
    body = shaped_noise(n, 150, 5000, tilt=0.6) * np.exp(-t * 7)
    bubbles = np.zeros(n)
    for _ in range(14):
        start = int(rng.uniform(0.05, 0.5) * SR)
        bt = np.arange(int(0.04 * SR)) / SR
        f = rng.uniform(500, 1400) * (1 + bt * 8)
        b = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-bt * 90)
        seg = b[: n - start]
        bubbles[start:start + len(seg)] += seg * rng.uniform(0.1, 0.3)
    out = (body + bubbles) * fade(n, 0.005, 0.2)
    return out / np.max(np.abs(out)) * 0.6


def anchor_chain(d=1.6):
    n = int(d * SR)
    out = np.zeros(n)
    k = np.arange(int(0.05 * SR)) / SR
    pos, gap = 0.0, 0.035
    while pos < d - 0.45:
        f = rng.uniform(1800, 3200)
        clink = np.exp(-k * 70) * (np.sin(2 * np.pi * f * k) + 0.5 * np.sin(2 * np.pi * f * 2.7 * k))
        i = int(pos * SR)
        seg = clink[: n - i]
        out[i:i + len(seg)] += seg * rng.uniform(0.4, 1.0)
        pos += gap * rng.uniform(0.7, 1.3)
        gap *= 1.04
    s = splash(0.6) * 0.8
    i = n - len(s)
    out[i:] += s
    out *= fade(n, 0.01, 0.15)
    return out / np.max(np.abs(out)) * 0.55


def cannon_fire(d=1.4):
    n = int(d * SR)
    t = np.arange(n) / SR
    boom = np.sin(2 * np.pi * (55 + 40 * np.exp(-t * 12)) * t) * np.exp(-t * 4.5)
    blast = shaped_noise(n, 40, 1800, tilt=0.9) * np.exp(-t * 9)
    crack = shaped_noise(n, 1500, 8000, tilt=0.2) * np.exp(-t * 60)
    out = boom * 0.9 + blast * 0.8 + crack * 0.3
    out *= fade(n, 0.002, 0.3)
    return out / np.max(np.abs(out)) * 0.85


def wood_hit(d=0.6):
    n = int(d * SR)
    t = np.arange(n) / SR
    crack = shaped_noise(n, 400, 6000, tilt=0.4) * np.exp(-t * 25)
    thud = np.sin(2 * np.pi * 110 * t) * np.exp(-t * 14)
    out = (crack * 0.8 + thud * 0.7 + creak(d) * 0.3) * fade(n, 0.001, 0.2)
    return out / np.max(np.abs(out)) * 0.7


def coin(d=0.45):
    n = int(d * SR)
    t = np.arange(n) / SR
    out = np.zeros(n)
    for start, f in [(0.0, 1900), (0.07, 2550)]:
        tt = np.clip(t - start, 0, None)
        out += (t >= start) * (np.sin(2 * np.pi * f * tt) + 0.3 * np.sin(2 * np.pi * f * 2.4 * tt)) * np.exp(-tt * 11)
    return out / np.max(np.abs(out)) * 0.4


def chest_open(d=0.9):
    n = int(d * SR)
    t = np.arange(n) / SR
    c = creak(0.6)
    out = np.zeros(n)
    out[: len(c)] += c
    i = int(0.6 * SR)
    tt = t[i:] - 0.6
    out[i:] += np.sin(2 * np.pi * 90 * tt) * np.exp(-tt * 18) * 0.8
    return out / np.max(np.abs(out)) * 0.6


def sword_swing(d=0.3):
    n = int(d * SR)
    t = np.arange(n) / SR
    out = shaped_noise(n, 800, 5000, tilt=0.3) * np.sin(np.pi * t / d) ** 2
    return out / np.max(np.abs(out)) * 0.35


def hurt(d=0.35):
    n = int(d * SR)
    t = np.arange(n) / SR
    f = 220 * np.exp(-t * 2.5)
    saw = 2 * ((np.cumsum(f) / SR) % 1.0) - 1
    out = (saw * 0.6 + shaped_noise(n, 200, 3000) * 0.3) * np.exp(-t * 9)
    return out / np.max(np.abs(out)) * 0.4


def ui_click(d=0.06):
    n = int(d * SR)
    t = np.arange(n) / SR
    out = np.sin(2 * np.pi * 1200 * t) * np.exp(-t * 90)
    return out / np.max(np.abs(out)) * 0.25


def gunshot(d=0.7):
    n = int(d * SR)
    t = np.arange(n) / SR
    crack = shaped_noise(n, 1200, 9000, tilt=0.2) * np.exp(-t * 70)
    body = shaped_noise(n, 60, 1500, tilt=0.8) * np.exp(-t * 14)
    out = crack * 0.9 + body * 0.7
    return out / np.max(np.abs(out)) * 0.7


def explosion(d=1.8):
    n = int(d * SR)
    t = np.arange(n) / SR
    boom = np.sin(2 * np.pi * (45 + 60 * np.exp(-t * 10)) * t) * np.exp(-t * 3.5)
    rumble = shaped_noise(n, 30, 900, tilt=1.0) * np.exp(-t * 3)
    debris = shaped_noise(n, 1500, 7000, tilt=0.3) * np.exp(-t * 12) * 0.4
    out = (boom + rumble + debris) * fade(n, 0.002, 0.5)
    return out / np.max(np.abs(out)) * 0.9


def fire_whoosh(d=1.2):
    n = int(d * SR)
    t = np.arange(n) / SR
    roar = shaped_noise(n, 100, 2500, tilt=0.9) * np.sin(np.pi * t / d) ** 0.7
    crackle = np.zeros(n)
    for _ in range(25):
        i = int(rng.uniform(0, d - 0.02) * SR)
        crackle[i:i + 200] += rng.uniform(-1, 1, 200) * np.exp(-np.arange(200) / 30)
    out = roar + crackle * 0.4
    return out / np.max(np.abs(out)) * 0.6


def gas_hiss(d=1.4):
    n = int(d * SR)
    t = np.arange(n) / SR
    out = shaped_noise(n, 2500, 9000, tilt=0.1) * np.minimum(t * 8, 1) * np.exp(-t * 1.5)
    return out / np.max(np.abs(out)) * 0.4


def flash_bang(d=1.0):
    n = int(d * SR)
    t = np.arange(n) / SR
    bang = shaped_noise(n, 800, 10000, tilt=0.1) * np.exp(-t * 30)
    ring = np.sin(2 * np.pi * 3200 * t) * np.exp(-t * 3) * 0.15
    out = bang + ring
    return out / np.max(np.abs(out)) * 0.7


def rain(length=10.0):
    """Regn: blød, bred støj med mange små dryp."""
    n = int(length * SR)
    channels = []
    for ch in range(2):
        hiss = shaped_noise(n, 400, 9000, tilt=0.35) * 0.35
        drops = np.zeros(n)
        for i in range(int(length * 70)):
            pos = rng.integers(0, n)
            d = int(SR * 0.012)
            tt = np.arange(d) / SR
            f = rng.uniform(2500, 6500)
            idx = (np.arange(d) + pos) % n
            drops[idx] += np.sin(2 * np.pi * f * tt) * np.exp(-tt * 400) * rng.uniform(0.05, 0.25)
        channels.append(hiss + drops)
    out = np.array(channels)
    return out / np.max(np.abs(out)) * 0.6


def thunder(d=4.5):
    """Torden: et skarpt knald efterfulgt af lang, dyb rumlen."""
    n = int(d * SR)
    t = np.arange(n) / SR
    crack = shaped_noise(n, 200, 5000, tilt=0.2) * np.exp(-t * 9) * 0.6
    rumble = shaped_noise(n, 25, 220, tilt=0.6)
    wobble = 0.6 + 0.4 * np.sin(2 * np.pi * 1.3 * t) * np.sin(2 * np.pi * 0.4 * t + 1.0)
    rumble *= np.minimum(t / 0.15, 1.0) * np.exp(-t * 0.9) * wobble
    out = crack + rumble * 1.4
    return out / np.max(np.abs(out)) * 0.85 * fade(n, 0.005, 1.0)


def anchor_drop(d=1.3):
    """Anker: et dumpt bump (træ mod jern) og et blødt plask – kun en antydning af kæde."""
    n = int(d * SR)
    t = np.arange(n) / SR
    pitch = 70 * (1 + 0.8 * np.exp(-t * 25))
    thump = np.sin(2 * np.pi * np.cumsum(pitch) / SR) * np.exp(-t * 9)
    knock = shaped_noise(n, 120, 900, tilt=0.4) * np.exp(-t * 35) * 0.6
    splash_t = np.clip(t - 0.12, 0, None)
    splash = shaped_noise(n, 300, 5000, tilt=0.3) * np.exp(-splash_t * 6) * (t > 0.12) * 0.35
    rattle = np.zeros(n)
    for i in range(4):
        pos = int((0.03 + i * 0.045) * SR)
        m = int(0.012 * SR)
        tt = np.arange(m) / SR
        rattle[pos:pos + m] += np.sin(2 * np.pi * rng.uniform(2200, 3200) * tt) * np.exp(-tt * 300) * 0.08
    out = thump * 1.0 + knock + splash + rattle
    return out / np.max(np.abs(out)) * 0.8 * fade(n, 0.002, 0.3)


if __name__ == "__main__":
    print("Genererer lyde:")
    write_wav(AMBIENCE / "ocean_loop.wav", ocean(), loop=True)
    write_wav(AMBIENCE / "wind_loop.wav", wind(), loop=True)
    for i, (calls, base) in enumerate([(3, 1250), (2, 1400), (4, 1150)], start=1):
        write_wav(SFX / f"gull_{i}.wav", gull(calls, base))
    write_wav(SFX / "creak.wav", creak())
    write_wav(SFX / "sail_flap.wav", sail_flap())
    write_wav(SFX / "splash.wav", splash())
    write_wav(SFX / "anchor_chain.wav", anchor_chain())
    write_wav(SFX / "cannon_fire.wav", cannon_fire())
    write_wav(SFX / "wood_hit.wav", wood_hit())
    write_wav(SFX / "coin.wav", coin())
    write_wav(SFX / "chest_open.wav", chest_open())
    write_wav(SFX / "sword_swing.wav", sword_swing())
    write_wav(SFX / "hurt.wav", hurt())
    write_wav(SFX / "ui_click.wav", ui_click())
    write_wav(SFX / "gunshot.wav", gunshot())
    write_wav(SFX / "explosion.wav", explosion())
    write_wav(SFX / "fire_whoosh.wav", fire_whoosh())
    write_wav(SFX / "gas_hiss.wav", gas_hiss())
    write_wav(SFX / "flash_bang.wav", flash_bang())
    write_wav(AMBIENCE / "rain_loop.wav", rain(), loop=True)
    write_wav(SFX / "thunder.wav", thunder())
    write_wav(SFX / "anchor_drop.wav", anchor_drop())
