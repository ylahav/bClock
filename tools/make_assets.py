"""Generates bClock's bundled assets, so they are original and reproducible.

    python tools/make_assets.py

Writes:
  assets/sounds/alarm.wav               "Beeps": the default ring (loops)
  assets/sounds/chime.wav               "Chime": two soft bell notes
  assets/sounds/pulse.wav               "Soft pulse": a slow, low swell
  assets/sounds/hour.wav                the hourly chime: one bell note
  assets/icons/app_icon.png             256 px: notifications
  assets/icons/tray_icon.png            64 px, bold: the tray icon
  assets/icons/app_icon_512.png         512 px: general use
  windows/runner/resources/app_icon.ico exe, taskbar and installer icon

Nothing here is third-party: the sound is synthesised below and the icon is
drawn below (bClock's own analog clock face). Both are covered by the
repository's MIT license. Needs Pillow (`pip install pillow`).
"""

import math
import struct
import wave
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent


# ── Sound ───────────────────────────────────────────────────────

RATE = 44100


def _beep(freq: float, seconds: float) -> list[float]:
    """A soft two-partial tone with a short fade in and out (no clicks)."""
    n = int(RATE * seconds)
    fade = int(RATE * 0.008)
    out = []
    for i in range(n):
        t = i / RATE
        s = 0.8 * math.sin(2 * math.pi * freq * t)
        s += 0.2 * math.sin(2 * math.pi * freq * 2 * t)
        env = min(1.0, i / fade, (n - 1 - i) / fade)
        out.append(s * env)
    return out


def _silence(seconds: float) -> list[float]:
    return [0.0] * int(RATE * seconds)


def make_alarm(path: Path) -> None:
    """Four quick beeps, then a rest: the classic alarm-clock pattern.

    Two seconds, and silent at both ends, so the player's loop is seamless.
    """
    samples: list[float] = []
    for i in range(4):
        # Alternate two notes a fourth apart so it reads as a ring, not a
        # fault tone.
        samples += _beep(1760.0 if i % 2 == 0 else 2349.3, 0.11)
        samples += _silence(0.09)
    samples += _silence(2.0 - len(samples) / RATE)
    _write(path, samples)


def _bell(freq: float, seconds: float) -> list[float]:
    """A struck-bell note: a quick attack, then a long exponential decay."""
    n = int(RATE * seconds)
    attack = int(RATE * 0.005)
    out = []
    for i in range(n):
        t = i / RATE
        s = 0.7 * math.sin(2 * math.pi * freq * t)
        s += 0.2 * math.sin(2 * math.pi * freq * 2.0 * t) * math.exp(-t * 6)
        s += 0.1 * math.sin(2 * math.pi * freq * 3.0 * t) * math.exp(-t * 9)
        out.append(s * min(1.0, i / attack) * math.exp(-t * 3.2))
    return out


def make_chime(path: Path) -> None:
    """Ding-dong: two bell notes a major third apart, then a rest.

    Three seconds; the second note has decayed to silence by the end.
    """
    samples = _bell(659.3, 0.9) + _bell(523.3, 1.6)
    samples += _silence(3.0 - len(samples) / RATE)
    # The decay never reaches exactly zero: fade the tail so the loop
    # doesn't click.
    fade = int(RATE * 0.02)
    end = int(RATE * 2.5)
    for i in range(fade):
        samples[end - fade + i] *= 1 - i / fade
    for i in range(end, len(samples)):
        samples[i] = 0.0
    _write(path, samples)


def make_hour_chime(path: Path) -> None:
    """One bell note, played once on the hour: short and unobtrusive."""
    samples = _bell(784.0, 1.4)
    fade = int(RATE * 0.05)
    for i in range(fade):
        samples[len(samples) - fade + i] *= 1 - i / fade
    samples[-1] = 0.0
    _write(path, samples)


def make_pulse(path: Path) -> None:
    """A low tone that swells and fades twice: the gentle option.

    Three seconds, silent at both ends.
    """
    samples: list[float] = []
    swell = int(RATE * 1.1)
    for _ in range(2):
        for i in range(swell):
            t = i / RATE
            env = math.sin(math.pi * i / swell) ** 2
            s = 0.75 * math.sin(2 * math.pi * 440.0 * t)
            s += 0.25 * math.sin(2 * math.pi * 660.0 * t)
            samples.append(s * env)
        samples += _silence(0.2)
    samples += _silence(3.0 - len(samples) / RATE)
    _write(path, samples)


def _write(path: Path, samples: list[float]) -> None:
    """16-bit mono WAV at 60% of full scale."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(
            b"".join(struct.pack("<h", int(s * 0.6 * 32767)) for s in samples)
        )


# ── Icon ────────────────────────────────────────────────────────

# The dark theme's clock face, with the brand colour on the second hand.
FACE = (17, 17, 17, 255)
RIM = (58, 58, 68, 255)
MAJOR_TICK = (224, 224, 228, 255)
MINOR_TICK = (96, 96, 104, 255)
HOUR_HAND = (224, 224, 228, 255)
MINUTE_HAND = (245, 245, 247, 255)
BRAND = (33, 150, 243, 255)  # AppTheme.brandColor, #2196F3

# Drawn large and scaled down, for smooth edges at every size.
CANVAS = 2048


def _point(cx: float, cy: float, angle_deg: float, r: float):
    """A point at [r] from the centre; 0 degrees is 12 o'clock, clockwise."""
    a = math.radians(angle_deg - 90)
    return (cx + r * math.cos(a), cy + r * math.sin(a))


def _hand(draw, c, angle, length, width, color, tail=0.0):
    draw.line(
        [_point(c, c, angle + 180, tail), _point(c, c, angle, length)],
        fill=color,
        width=width,
    )
    # Round the ends.
    for p in (_point(c, c, angle, length), _point(c, c, angle + 180, tail)):
        r = width / 2
        draw.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=color)


def draw_clock(weight: float = 1.0, ticks: str = "all") -> Image.Image:
    """The clock face.

    Small icons are drawn bolder rather than just scaled down, or the hands
    disappear: [weight] multiplies every stroke, and [ticks] is "all",
    "hours" or "quarters".
    """
    img = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = CANVAS / 2
    radius = CANVAS * 0.485

    d.ellipse([c - radius, c - radius, c + radius, c + radius], fill=RIM)
    face = radius - CANVAS * 0.012 * weight
    d.ellipse([c - face, c - face, c + face, c + face], fill=FACE)

    for i in range(60):
        major = i % 5 == 0
        if ticks == "hours" and not major:
            continue
        if ticks == "quarters" and i % 15 != 0:
            continue
        outer = face - CANVAS * 0.03
        inner = outer - CANVAS * (0.055 if major else 0.022) * min(weight, 2)
        d.line(
            [_point(c, c, i * 6, inner), _point(c, c, i * 6, outer)],
            fill=MAJOR_TICK if major else MINOR_TICK,
            width=int(CANVAS * (0.011 if major else 0.004) * weight),
        )

    # 2:20:33, the hands well apart.
    _hand(d, c, 62, face * 0.50, int(CANVAS * 0.026 * weight), HOUR_HAND)
    _hand(d, c, 120, face * 0.72, int(CANVAS * 0.014 * weight), MINUTE_HAND)
    _hand(d, c, 200, face * 0.78, int(CANVAS * 0.006 * weight * 1.6), BRAND,
          tail=face * 0.1)

    hub = CANVAS * 0.03 * min(weight, 2.5)
    d.ellipse([c - hub, c - hub, c + hub, c + hub], fill=BRAND)
    hole = hub * 0.45
    d.ellipse([c - hole, c - hole, c + hole, c + hole], fill=FACE)
    return img


def make_icons() -> None:
    # (largest size it is used for, weight, ticks)
    styles = [
        (20, draw_clock(weight=4.2, ticks="quarters")),
        (32, draw_clock(weight=3.0, ticks="hours")),
        (48, draw_clock(weight=2.2, ticks="hours")),
        (128, draw_clock(weight=1.4, ticks="all")),
        (10**6, draw_clock()),
    ]

    def sized(px: int) -> Image.Image:
        source = next(img for limit, img in styles if px <= limit)
        return source.resize((px, px), Image.LANCZOS)

    icons = ROOT / "assets" / "icons"
    icons.mkdir(parents=True, exist_ok=True)
    sized(256).save(icons / "app_icon.png")
    sized(512).save(icons / "app_icon_512.png")
    # Windows scales the tray image down to 16-32 px, so it is drawn in the
    # bold small-size style rather than taken from the 256 px icon.
    draw_clock(weight=3.0, ticks="hours").resize((64, 64), Image.LANCZOS).save(
        icons / "tray_icon.png"
    )

    ico_sizes = [16, 20, 24, 32, 40, 48, 64, 128, 256]
    frames = [sized(px) for px in ico_sizes]
    frames[-1].save(
        ROOT / "windows" / "runner" / "resources" / "app_icon.ico",
        format="ICO",
        append_images=frames[:-1],
        sizes=[(px, px) for px in ico_sizes],
    )


if __name__ == "__main__":
    sounds = ROOT / "assets" / "sounds"
    make_alarm(sounds / "alarm.wav")
    make_chime(sounds / "chime.wav")
    make_pulse(sounds / "pulse.wav")
    make_hour_chime(sounds / "hour.wav")
    make_icons()
    print("Assets written.")
