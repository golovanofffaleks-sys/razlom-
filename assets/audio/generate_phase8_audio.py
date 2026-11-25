"""Синтез звуков боя, Разлома и ветра для Фазы 8."""

from math import exp, pi, sin, tanh
from pathlib import Path
from random import Random
from struct import pack
import wave

RATE = 24000
TAU = 2.0 * pi
AUDIO = Path(__file__).resolve().parent


def fade(t, duration, attack, release):
    return min(1.0, t / attack, max(0.0, (duration - t) / release))


def pcm(name, samples, channels=1, loop=False):
    payload = b"".join(pack("<h", round(max(-1.0, min(1.0, x)) * 32760)) for x in samples)
    file = AUDIO / (name + ".wav")
    with wave.open(str(file), "wb") as handle:
        handle.setnchannels(channels)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(payload)
    if loop:
        end = len(payload) // (channels * 2) - 1
        smpl = pack("<15I", 0, 0, round(1e9 / RATE), 60, 0, 0, 0, 1, 0,
                    0, 0, 0, end, 0, 0)
        with file.open("r+b") as handle:
            handle.seek(0, 2)
            handle.write(b"smpl" + pack("<I", len(smpl)) + smpl)
            size = handle.tell()
            handle.seek(4)
            handle.write(pack("<I", size - 8))


def foley(name, duration, seed, tone):
    rng = Random(seed)
    previous = 0.0
    smooth = 0.0
    output = []
    for i in range(round(RATE * duration)):
        t = i / RATE
        noise = rng.uniform(-1, 1)
        smooth += (noise - smooth) * 0.14
        sample = tone(t, noise, smooth, noise - previous)
        previous = noise
        output.append(tanh(sample) * fade(t, duration, 0.012, 0.065))
    pcm(name, output)


def bow(t, noise, smooth, edge):
    tension = (t / 0.38) ** 0.8
    creak = sin(TAU * (89*t + 163*t*t)) + 0.42*sin(TAU * (234*t + 108*t*t))
    fibres = sum(exp(-abs(t - cue) * 260) for cue in (0.08, 0.17, 0.24, 0.32))
    return (0.075 + 0.22 * tension) * creak * (0.65 + 0.35*sin(TAU * 23*t)) + smooth * 0.5 + edge * fibres * 0.34


def arrow(t, noise, smooth, edge):
    whistle = sin(TAU*(1480*t + 133*t*t)) + 0.27*sin(TAU*(2450*t - 215*t*t))
    release = exp(-34*t) * (0.61*sin(TAU*(195*t-40*t*t)) + edge*0.4)
    return release + (0.24*whistle + 0.34*smooth + 0.12*noise) * exp(-4.0*t)


def sword(t, noise, smooth, edge):
    sweep = exp(-((t - 0.093) / 0.073) ** 2)
    air = (0.76 * smooth + 0.38 * noise + 0.19 * edge) * sweep
    whir = sin(TAU*(430*t - 590*t*t)) * sweep * 0.19
    metal = (sin(TAU*1379*t) + 0.34*sin(TAU*2038*t)) * exp(-14*t) * 0.075
    return air + whir + metal


def rift_loop():
    duration = 4.0
    values = []
    for i in range(round(RATE * duration)):
        t = i / RATE
        pulse = 0.72 + 0.18 * sin(TAU * 1.25 * t) + 0.10 * sin(TAU * 0.5 * t)
        throat = 0.30*sin(TAU*48*t) + 0.15*sin(TAU*71*t) + 0.11*sin(TAU*108*t + 0.42*sin(TAU*0.75*t))
        overtone = 0.052*sin(TAU*221.5*t) + 0.037*sin(TAU*318.25*t + sin(TAU*0.5*t))
        values.append(tanh(pulse * (throat + overtone)))
    pcm("rift_hum", values, loop=True)


def wind_loop():
    duration = 12
    frames = RATE * duration
    rng = Random(6103)
    sources = [[rng.uniform(-1, 1) for _ in range(frames)] for _ in range(2)]
    output = []
    filters = [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0]]
    for cycle in range(2):
        for index in range(frames):
            t = index / RATE
            phase = TAU*t/duration
            gust = 0.49 + 0.27*sin(3*phase+0.8) + 0.18*sin(5*phase-0.4)
            drift = sin(phase+0.7)*0.11
            chord = 0.019*sin(phase*1320) + 0.016*sin(phase*1569 + 0.38*sin(phase*2)) + 0.013*sin(phase*2354 + 0.27*sin(phase))
            whistle = 0.032*sin(phase*5080 + 3.1*sin(phase*4)) * max(0, sin(phase*2-0.7))**2
            for channel, panning in ((0, -1), (1, 1)):
                low, mid, high = filters[channel]
                noise = 0.67*sources[0][index] + 0.33*sources[channel][index]
                low += 0.0027*(noise-low)
                mid += 0.035*(noise-mid)
                high += 0.19*(noise-high)
                filters[channel] = [low, mid, high]
                if cycle:
                    breath = (3.0*low + 1.0*mid + 0.21*high) * (gust + panning*drift)
                    output.append(tanh(breath + chord * (0.85 + 0.15*sin(phase+panning)) + whistle))
    pcm("ruins_wind", output, channels=2, loop=True)


if __name__ == "__main__":
    foley("bow_draw", 0.38, 123, bow)
    foley("arrow_whistle", 0.61, 435, arrow)
    foley("sword_swing", 0.28, 561, sword)
    rift_loop()
    wind_loop()
