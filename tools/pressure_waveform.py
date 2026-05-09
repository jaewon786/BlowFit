"""Realistic bidirectional respiratory pressure waveform generator.

Models one breathing cycle (v4.0 양방향 — XGZP6847A010KPGPN33 ±102 cmH₂O):
  - Inhale (2.0 s): negative pressure (suction) bell curve 0 → -peak*0.75 → 0
  - Exhale onset ramp (0.6 s): 0 → peak
  - Exhale hold (3.5 s): near peak with small jitter (target zone)
  - Exhale release (0.5 s): peak → 0
  - Pause (0.8 s): ~0

Peak is configurable per orifice level. v3.2 backward compat: set
`bidirectional=False` to suppress negative pressure (양압 전용 시뮬레이션).
"""

from __future__ import annotations

import math
import random
from dataclasses import dataclass


@dataclass
class BreathingConfig:
    peak_cmh2o: float = 25.0      # target peak during exhale
    sample_rate_hz: int = 100
    jitter_cmh2o: float = 1.2     # random noise during hold
    inhale_sec: float = 2.0
    ramp_up_sec: float = 0.6
    hold_sec: float = 3.5
    ramp_down_sec: float = 0.5
    pause_sec: float = 0.8
    # v4.0 양방향 — 흡기 phase 에 음압 발생. False 면 v3.2 (양압 전용) 동작.
    bidirectional: bool = True
    # 흡기 peak 는 호기 peak 의 비율로 — 일반적으로 흡기근이 약함.
    inhale_peak_ratio: float = 0.75

    @property
    def cycle_sec(self) -> float:
        return (self.inhale_sec + self.ramp_up_sec + self.hold_sec
                + self.ramp_down_sec + self.pause_sec)


class WaveformGenerator:
    """Streams pressure samples at a fixed rate as an iterator."""

    def __init__(self, cfg: BreathingConfig | None = None, seed: int | None = None):
        self.cfg = cfg or BreathingConfig()
        self._rng = random.Random(seed)
        self._t = 0.0
        self._dt = 1.0 / self.cfg.sample_rate_hz

    def set_peak(self, peak_cmh2o: float) -> None:
        self.cfg.peak_cmh2o = max(0.0, peak_cmh2o)

    def next_sample(self) -> float:
        """Return next pressure sample in cmH2O and advance time."""
        t = self._t % self.cfg.cycle_sec
        self._t += self._dt
        return self._pressure_at(t)

    def _pressure_at(self, t: float) -> float:
        c = self.cfg
        start = 0.0

        # Inhale — v4.0 양방향: bell curve 음압. v3.2: 거의 0 (passive).
        if t < start + c.inhale_sec:
            if c.bidirectional:
                # 0 → -peak*ratio → 0 over inhale_sec, smooth sin-bell.
                x = (t - start) / c.inhale_sec  # 0 ~ 1
                inhale_val = -math.sin(x * math.pi) * c.peak_cmh2o * c.inhale_peak_ratio
                return inhale_val + self._noise(0.5)
            return self._noise(0.3)
        start += c.inhale_sec

        # Ramp up (smooth-step)
        if t < start + c.ramp_up_sec:
            x = (t - start) / c.ramp_up_sec
            eased = 3 * x * x - 2 * x * x * x  # smoothstep
            return c.peak_cmh2o * eased + self._noise(0.5)
        start += c.ramp_up_sec

        # Hold near peak
        if t < start + c.hold_sec:
            return c.peak_cmh2o + self._noise(c.jitter_cmh2o)
        start += c.hold_sec

        # Ramp down
        if t < start + c.ramp_down_sec:
            x = (t - start) / c.ramp_down_sec
            eased = 1 - (3 * x * x - 2 * x * x * x)
            return c.peak_cmh2o * eased + self._noise(0.5)
        start += c.ramp_down_sec

        # Pause
        return self._noise(0.2)

    def _noise(self, sigma: float) -> float:
        return self._rng.gauss(0.0, sigma)


if __name__ == "__main__":
    # Sanity check: print one full cycle as CSV for spreadsheet plotting.
    gen = WaveformGenerator(BreathingConfig(peak_cmh2o=25.0), seed=0)
    samples_per_cycle = int(gen.cfg.cycle_sec * gen.cfg.sample_rate_hz)
    print("t_sec,cmh2o")
    for i in range(samples_per_cycle):
        print(f"{i * gen._dt:.3f},{gen.next_sample():.2f}")
