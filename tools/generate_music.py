"""Komponerer spillets baggrundsmusik i kode: rolig, caribisk inspireret pirat-musik.

Kør fra projektets rod:  python3 tools/generate_music.py
Kræver numpy og ffmpeg (til .ogg). Hvert nummer looper sømløst.

Numre:
  day     – "Solskin på havet": calypso-guitar, marimba, bas og shaker (F-dur, 96 bpm)
  night   – "Stjernenat": bløde guitar-arpeggier, fløjte og strygerflade (d-mol, 70 bpm)
  harbor  – "Havnekroen": steeldrum, guitar og lette trommer (G-dur, 110 bpm)
  battle  – "Sabler i solen": drivende bas, håndtrommer og fløjte (a-mol, 126 bpm)

Instrumenterne er syntetiske (additiv syntese) – de kan erstattes af rigtige optagelser senere,
bare med samme filnavne i assets/audio/music/.
"""
import subprocess
import wave
from pathlib import Path

import numpy as np

SR = 32000
ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "audio" / "music"
NOTE_NAMES = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6,
              "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


def midi(name, octave):
    return 12 * (octave + 1) + NOTE_NAMES[name]


def freq(m):
    return 440.0 * 2 ** ((m - 69) / 12)


# --- Instrumenter --------------------------------------------------------------

def env_adsr(n, a, d, s, r, sustain_len):
    """Simpel ADSR-kurve (i sekunder)."""
    t = np.arange(n) / SR
    env = np.zeros(n)
    a = max(a, 1e-3)
    env = np.where(t < a, t / a, env)
    dmask = (t >= a) & (t < a + d)
    env = np.where(dmask, 1 - (1 - s) * (t - a) / max(d, 1e-3), env)
    smask = (t >= a + d) & (t < sustain_len)
    env = np.where(smask, s, env)
    rmask = t >= sustain_len
    env = np.where(rmask, s * np.exp(-(t - sustain_len) / max(r, 1e-3)), env)
    return env


def guitar(f, dur, vel=1.0, rng=None):
    """Nylonstrengs-guitar: harmoniske overtoner, der dør hurtigere jo højere de er."""
    n = int(SR * (dur + 1.2))
    t = np.arange(n) / SR
    out = np.zeros(n)
    for k in range(1, 9):
        fk = f * k * (1 + 0.0004 * k * k)
        if fk > SR / 2.2:
            break
        amp = (1.0 / k ** 1.3) * (1.0 if k != 2 else 0.8)
        out += amp * np.sin(2 * np.pi * fk * t) * np.exp(-t * (2.2 + 1.3 * k))
    attack = np.minimum(t / 0.004, 1.0)
    out *= attack
    damp = np.where(t > dur, np.exp(-(t - dur) / 0.08), 1.0) # strengen dæmpes
    return out * damp * vel * 0.5


def marimba(f, dur, vel=1.0, rng=None):
    n = int(SR * 1.4)
    t = np.arange(n) / SR
    out = np.sin(2 * np.pi * f * t) * np.exp(-t * 3.2)
    out += 0.3 * np.sin(2 * np.pi * f * 3.98 * t) * np.exp(-t * 12.0)
    out += 0.08 * np.sin(2 * np.pi * f * 9.9 * t) * np.exp(-t * 30.0)
    out *= np.minimum(t / 0.002, 1.0)
    return out * vel * 0.55


def steelpan(f, dur, vel=1.0, rng=None):
    n = int(SR * 1.8)
    t = np.arange(n) / SR
    out = np.sin(2 * np.pi * f * t) * np.exp(-t * 2.0)
    out += 0.5 * np.sin(2 * np.pi * f * 2.005 * t) * np.exp(-t * 2.6)
    out += 0.25 * np.sin(2 * np.pi * f * 3.01 * t) * np.exp(-t * 4.0)
    out += 0.12 * np.sin(2 * np.pi * f * 4.2 * t) * np.exp(-t * 8.0)
    out *= np.minimum(t / 0.006, 1.0)
    return out * vel * 0.42


def flute(f, dur, vel=1.0, rng=None):
    n = int(SR * (dur + 0.5))
    t = np.arange(n) / SR
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.2 * t) * np.minimum(t / 0.4, 1.0)
    phase = 2 * np.pi * f * np.cumsum(vib) / SR
    out = np.sin(phase) + 0.18 * np.sin(2 * phase) + 0.06 * np.sin(3 * phase)
    breath = (rng.standard_normal(n) if rng is not None else np.random.standard_normal(n))
    breath = np.convolve(breath, np.ones(12) / 12, mode="same") * 0.05
    out = out + breath
    out *= env_adsr(n, 0.07, 0.15, 0.8, 0.18, dur)
    return out * vel * 0.32


def bass(f, dur, vel=1.0, rng=None):
    n = int(SR * (dur + 0.6))
    t = np.arange(n) / SR
    out = np.sin(2 * np.pi * f * t) + 0.35 * np.sin(4 * np.pi * f * t) * np.exp(-t * 6) + 0.1 * np.sin(6 * np.pi * f * t) * np.exp(-t * 10)
    out *= np.exp(-t * 1.6) * np.minimum(t / 0.008, 1.0)
    out *= np.where(t > dur, np.exp(-(t - dur) / 0.06), 1.0)
    return out * vel * 0.6


def pad(f, dur, vel=1.0, rng=None):
    """Blød strygerflade: flere let forstemte toner med langsom ind- og udtoning."""
    n = int(SR * (dur + 1.5))
    t = np.arange(n) / SR
    out = np.zeros(n)
    for det in (-0.003, 0.0, 0.004):
        ph = 2 * np.pi * f * (1 + det) * t
        out += np.sin(ph) + 0.3 * np.sin(2 * ph) + 0.12 * np.sin(3 * ph)
    out *= env_adsr(n, 0.9, 0.4, 0.85, 1.0, dur)
    return out * vel * 0.12


def shaker(dur, vel, rng):
    n = int(SR * 0.09)
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    noise = np.diff(np.concatenate([[0], noise])) # høj-pas: en "tsk"-lyd
    return noise * np.exp(-t * 55) * np.minimum(t / 0.006, 1.0) * vel * 0.12


def conga(f, dur, vel, rng):
    n = int(SR * 0.4)
    t = np.arange(n) / SR
    pitch = f * (1 + 0.6 * np.exp(-t * 40))
    out = np.sin(2 * np.pi * np.cumsum(pitch) / SR) * np.exp(-t * 11)
    out += rng.standard_normal(n) * np.exp(-t * 90) * 0.15
    return out * vel * 0.5


# --- Mixer ------------------------------------------------------------------------

class Track:
    def __init__(self, bpm, bars, beats_per_bar=4, seed=1):
        self.bpm = bpm
        self.beat = 60.0 / bpm
        self.bars = bars
        self.bpb = beats_per_bar
        self.length = int(round(SR * self.beat * beats_per_bar * bars))
        self.buses = {}
        self.rng = np.random.default_rng(seed)

    def add(self, bus, sound, start_beat, pan=0.0):
        """Lægger en lyd ind; hvad der stikker ud over enden, lægges ind i starten (sømløst loop)."""
        start = int(round(start_beat * self.beat * SR))
        start += int(self.rng.normal(0, 0.004) * SR) # lidt menneskelig unøjagtighed
        start %= self.length
        buf = self.buses.setdefault(bus, np.zeros((2, self.length)))
        l = np.cos((pan + 1) * np.pi / 4)
        r = np.sin((pan + 1) * np.pi / 4)
        idx = (np.arange(len(sound)) + start) % self.length
        np.add.at(buf[0], idx, sound * l)
        np.add.at(buf[1], idx, sound * r)

    def note(self, bus, inst, m, start_beat, dur_beats, vel=1.0, pan=0.0):
        self.add(bus, inst(freq(m), dur_beats * self.beat, vel, self.rng), start_beat, pan)

    def mix(self, gains, reverb):
        out = np.zeros((2, self.length))
        wet = np.zeros((2, self.length))
        for bus, buf in self.buses.items():
            g = gains.get(bus, 1.0)
            out += buf * g
            wet += buf * g * reverb.get(bus, 0.2)
        out += circular_reverb(wet, self.rng)
        # Blød kompressor/limiter
        peak = np.max(np.abs(out))
        out = np.tanh(out / peak * 1.3) / np.tanh(1.3) * 0.72
        return out


def circular_reverb(sig, rng, seconds=1.8):
    """Rumklang via cirkulær foldning (FFT), så halen også looper."""
    n = sig.shape[1]
    t = np.arange(int(SR * seconds)) / SR
    out = np.zeros_like(sig)
    for ch in range(2):
        ir = rng.standard_normal(len(t)) * np.exp(-t * 3.5)
        ir = np.convolve(ir, np.ones(6) / 6, mode="same") # lidt mørkere klang
        ir[:int(SR * 0.012)] = 0
        ir_full = np.zeros(n)
        ir_full[:len(ir)] = ir
        out[ch] = np.real(np.fft.ifft(np.fft.fft(sig[ch]) * np.fft.fft(ir_full)))
    return out / (np.max(np.abs(out)) + 1e-9) * np.max(np.abs(sig)) * 0.9


# --- Musikteori ---------------------------------------------------------------------

CHORDS = {
    "": [0, 4, 7], "m": [0, 3, 7], "7": [0, 4, 7, 10], "maj7": [0, 4, 7, 11], "m7": [0, 3, 7, 10],
    "m9": [0, 3, 7, 10, 14], "sus": [0, 5, 7], "6": [0, 4, 7, 9], "add9": [0, 4, 7, 14],
}


def chord(symbol, octave=3):
    root = symbol[:2] if len(symbol) > 1 and symbol[1] in "#b" else symbol[:1]
    kind = symbol[len(root):]
    base = midi(root, octave)
    return base, [base + i for i in CHORDS[kind]]


def scale_notes(key_root, minor, low, high):
    steps = [0, 2, 3, 5, 7, 8, 10] if minor else [0, 2, 4, 5, 7, 9, 11]
    root = NOTE_NAMES[key_root]
    return [m for m in range(low, high + 1) if (m - root) % 12 in steps]


def nearest(pool, target):
    return min(pool, key=lambda m: abs(m - target))


def melody(track, inst, bus, progression, scale, rhythms, start_bar, bars, low, high, vel=0.8, pan=0.2, seed=0, rest_chance=0.0):
    """Enkel melodi: motivet gentages og tilpasses akkorderne, med trinvise bevægelser."""
    rng = np.random.default_rng(seed)
    pool = [m for m in scale if low <= m <= high]
    current = nearest(pool, (low + high) // 2)
    motif = [rng.integers(-2, 3) for _ in range(8)]
    for b in range(bars):
        bar = start_bar + b
        _, tones = chord(progression[bar % len(progression)], 5)
        chord_pool = [m for m in pool if (m % 12) in [t % 12 for t in tones]]
        rhythm = rhythms[(b // 2) % len(rhythms)] if b % 4 != 3 else rhythms[-1]
        for i, (pos, dur) in enumerate(rhythm):
            if rng.random() < rest_chance:
                continue
            strong = pos % 2 == 0
            step = motif[i % len(motif)] if b % 2 == 0 else -motif[i % len(motif)]
            idx = pool.index(current) if current in pool else 0
            idx = int(np.clip(idx + step, 0, len(pool) - 1))
            current = pool[idx]
            if strong and chord_pool:
                current = nearest(chord_pool, current)
            track.note(bus, inst, current, bar * track.bpb + pos, dur, vel * (1.0 if strong else 0.8), pan)


# --- Numrene ----------------------------------------------------------------------------

def day_track():
    tr = Track(96, 32, seed=11)
    prog = ["F", "Bb", "C7", "F", "Dm", "Gm", "C7", "F",
            "F", "Bb", "C7", "Am", "Dm", "Gm7", "C7", "F"]
    for bar in range(tr.bars):
        root, tones = chord(prog[bar % len(prog)], 3)
        base = bar * 4
        # Calypso-anslag: x . x x . x x .
        for i, pos in enumerate([0, 1, 1.5, 2.5, 3]):
            v = 0.55 if i in (0, 3) else 0.38
            for j, m in enumerate(sorted(tones)[:4]):
                tr.note("guitar", guitar, m + 12, base + pos + j * 0.012, 0.4, v, -0.3)
        # Bas: grundtone og kvint, med et lille synkopet trin
        tr.note("bass", bass, root - 12, base, 1.4, 0.9)
        tr.note("bass", bass, root - 5, base + 1.5, 0.5, 0.6)
        tr.note("bass", bass, root - 12 + (12 if bar % 2 else 7), base + 2, 1.4, 0.75)
        tr.note("bass", bass, root - 10, base + 3.5, 0.4, 0.5)
        for k in range(8):
            tr.add("perc", shaker(0.1, 0.9 if k % 2 else 0.5, tr.rng), base + k * 0.5, 0.4)
        if bar % 2 == 1:
            tr.add("perc", conga(220, 0.2, 0.5, tr.rng), base + 3.5, -0.4)
    scale = scale_notes("F", False, 60, 86)
    rhythms = [[(0, 1), (1, 0.5), (1.5, 1), (2.5, 0.5), (3, 1)], [(0, 1.5), (1.5, 0.5), (2, 1), (3, 0.5), (3.5, 0.5)], [(0, 3)]]
    melody(tr, marimba, "lead", prog, scale, rhythms, 0, 16, 65, 84, 0.75, 0.25, seed=3)
    melody(tr, flute, "lead2", prog, scale, rhythms[1:], 16, 16, 67, 86, 0.6, -0.15, seed=7)
    melody(tr, marimba, "lead", prog, scale, rhythms, 24, 8, 60, 77, 0.45, 0.35, seed=5, rest_chance=0.35)
    return tr.mix({"guitar": 0.8, "bass": 1.0, "perc": 0.7, "lead": 0.85, "lead2": 0.7},
                  {"guitar": 0.2, "bass": 0.05, "perc": 0.15, "lead": 0.3, "lead2": 0.4})


def night_track():
    tr = Track(70, 16, seed=21)
    prog = ["Dm9", "Bbmaj7", "Gm7", "A7", "Dm9", "Fmaj7", "Gm7", "Asus"]
    for bar in range(tr.bars):
        root, tones = chord(prog[bar % len(prog)], 3)
        base = bar * 4
        arp = sorted(tones)
        pattern = [0, 2, 1, 3, 2, 1, 3, 2] if len(arp) > 3 else [0, 1, 2, 1, 0, 2, 1, 2]
        for k, p in enumerate(pattern):
            m = arp[p % len(arp)] + 12
            tr.note("guitar", guitar, m, base + k * 0.5, 1.2, 0.42 if k % 2 else 0.5, -0.25 + 0.06 * k)
        tr.note("bass", bass, root - 12, base, 3.5, 0.55)
        for m in arp[:3]:
            tr.note("pad", pad, m + 12, base, 3.9, 0.8, 0.1)
    scale = scale_notes("D", True, 62, 86)
    rhythms = [[(0, 2), (2, 1), (3, 1)], [(0, 3), (3, 1)], [(0, 4)]]
    melody(tr, flute, "lead", prog, scale, rhythms, 4, 8, 66, 84, 0.5, 0.2, seed=9, rest_chance=0.2)
    melody(tr, marimba, "lead2", prog, scale, [[(0, 1), (1.5, 1), (3, 1)], [(0.5, 1), (2, 2)]], 12, 4, 70, 86, 0.35, -0.3, seed=4, rest_chance=0.3)
    return tr.mix({"guitar": 0.8, "bass": 0.8, "pad": 1.0, "lead": 0.8, "lead2": 0.7},
                  {"guitar": 0.35, "bass": 0.1, "pad": 0.5, "lead": 0.5, "lead2": 0.5})


def harbor_track():
    tr = Track(110, 32, seed=31)
    prog = ["G", "C", "D7", "G", "Em", "C", "A7", "D7", "G", "C", "D7", "Em", "C", "D", "G", "G"]
    for bar in range(tr.bars):
        root, tones = chord(prog[bar % len(prog)], 3)
        base = bar * 4
        for pos in [0.5, 1.5, 2.5, 3.5]: # off-beat anslag
            for j, m in enumerate(sorted(tones)[:3]):
                tr.note("guitar", guitar, m + 12, base + pos + j * 0.01, 0.3, 0.42, -0.35)
        tr.note("bass", bass, root - 12, base, 0.9, 0.85)
        tr.note("bass", bass, root - 5, base + 2, 0.9, 0.7)
        tr.note("bass", bass, root - 12 + 12, base + 3, 0.4, 0.45)
        for k in range(8):
            tr.add("perc", shaker(0.1, 0.8 if k % 2 else 0.4, tr.rng), base + k * 0.5, 0.45)
        tr.add("perc", conga(180, 0.2, 0.6, tr.rng), base + 1, -0.4)
        tr.add("perc", conga(260, 0.2, 0.45, tr.rng), base + 2.5, -0.4)
        tr.add("perc", conga(260, 0.2, 0.4, tr.rng), base + 3, -0.4)
    scale = scale_notes("G", False, 62, 88)
    rhythms = [[(0, 0.5), (0.5, 0.5), (1, 1), (2, 0.5), (2.5, 1.5)], [(0, 1), (1, 0.5), (1.5, 0.5), (2, 1), (3, 1)], [(0, 2), (2, 2)]]
    melody(tr, steelpan, "lead", prog, scale, rhythms, 0, 32, 67, 88, 0.7, 0.25, seed=12)
    return tr.mix({"guitar": 0.75, "bass": 0.95, "perc": 0.7, "lead": 0.9},
                  {"guitar": 0.2, "bass": 0.05, "perc": 0.15, "lead": 0.3})


def battle_track():
    tr = Track(126, 32, seed=41)
    prog = ["Am", "Am", "F", "G", "Am", "Dm", "E7", "E7", "F", "G", "Am", "Am", "Dm", "F", "E7", "E7"]
    for bar in range(tr.bars):
        root, tones = chord(prog[bar % len(prog)], 3)
        base = bar * 4
        # Drivende bas i ottendedele
        for k in range(8):
            m = root - 12 + (12 if k in (3, 6) else 0)
            tr.note("bass", bass, m, base + k * 0.5, 0.4, 0.75 if k % 2 == 0 else 0.55)
        for pos in [0, 0.75, 1.5, 2.5, 3.25]:
            for j, m in enumerate(sorted(tones)[:3]):
                tr.note("guitar", guitar, m + 12, base + pos + j * 0.008, 0.25, 0.4, -0.3)
        tr.add("perc", conga(110, 0.3, 0.9, tr.rng), base, 0.0)
        tr.add("perc", conga(110, 0.3, 0.6, tr.rng), base + 1.5, 0.0)
        tr.add("perc", conga(110, 0.3, 0.8, tr.rng), base + 2, 0.0)
        tr.add("perc", conga(240, 0.2, 0.5, tr.rng), base + 1, -0.4)
        tr.add("perc", conga(240, 0.2, 0.5, tr.rng), base + 3, -0.4)
        tr.add("perc", conga(300, 0.2, 0.35, tr.rng), base + 3.5, 0.4)
        for k in range(8):
            tr.add("perc", shaker(0.1, 0.7, tr.rng), base + k * 0.5, 0.45)
    scale = scale_notes("A", True, 64, 88)
    scale = sorted(set(scale + [m for m in range(64, 89) if m % 12 == 8])) # harmonisk mol (g#)
    rhythms = [[(0, 1.5), (1.5, 0.5), (2, 1), (3, 1)], [(0, 0.5), (0.5, 0.5), (1, 0.5), (1.5, 1.5), (3, 1)], [(0, 2), (2, 2)]]
    melody(tr, flute, "lead", prog, scale, rhythms, 8, 24, 69, 88, 0.6, 0.2, seed=17)
    melody(tr, marimba, "lead2", prog, scale, rhythms[1:], 0, 8, 64, 81, 0.6, -0.25, seed=19)
    return tr.mix({"guitar": 0.65, "bass": 1.0, "perc": 0.85, "lead": 0.75, "lead2": 0.7},
                  {"guitar": 0.2, "bass": 0.05, "perc": 0.12, "lead": 0.35, "lead2": 0.3})


def write(name, data):
    OUT.mkdir(parents=True, exist_ok=True)
    wav_path = OUT / f"{name}.tmp.wav"
    pcm = (np.clip(data.T, -1, 1) * 32767).astype("<i2")
    with wave.open(str(wav_path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    ogg = OUT / f"{name}.ogg"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav_path), "-c:a", "libvorbis", "-q:a", "4", str(ogg)], check=True)
    wav_path.unlink()
    print(f"{ogg.name}: {data.shape[1] / SR:.1f} s")


if __name__ == "__main__":
    write("day", day_track())
    write("night", night_track())
    write("harbor", harbor_track())
    write("battle", battle_track())
