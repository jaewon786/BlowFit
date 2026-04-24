"""BlowFit BLE Simulator — virtual GATT peripheral for app development.

Advertises the same BlowFit Training Service as the real device, so the Flutter
app can scan, connect, and receive realistic pressure streams WITHOUT hardware.

Unblocks app development while firmware is still being built. This is the
critical lifeline from the SW Ultraplan.

Usage:
    pip install -r requirements.txt
    python ble-sim.py

Dependencies:
    bless >= 0.2.6  (cross-platform BLE peripheral)

Protocol: see docs/ble-protocol.md v1.0
"""

from __future__ import annotations

import asyncio
import logging
import struct
import sys
import time
from typing import Any

from bless import (
    BlessGATTCharacteristic,
    BlessServer,
    GATTAttributePermissions,
    GATTCharacteristicProperties,
)

from pressure_waveform import BreathingConfig, WaveformGenerator

# ---------------------------------------------------------------------------
# Protocol constants (MUST match docs/ble-protocol.md and firmware/ble_uuids.h)
# ---------------------------------------------------------------------------

DEVICE_NAME = "BlowFit-SIM"

SERVICE_UUID            = "0000b410-0000-1000-8000-00805f9b34fb"
PRESSURE_STREAM_UUID    = "0000b411-0000-1000-8000-00805f9b34fb"
SESSION_CONTROL_UUID    = "0000b412-0000-1000-8000-00805f9b34fb"
SESSION_SUMMARY_UUID    = "0000b413-0000-1000-8000-00805f9b34fb"
DEVICE_STATE_UUID       = "0000b414-0000-1000-8000-00805f9b34fb"
HISTORY_LIST_UUID       = "0000b415-0000-1000-8000-00805f9b34fb"

BATTERY_SERVICE_UUID    = "0000180f-0000-1000-8000-00805f9b34fb"
BATTERY_LEVEL_UUID      = "00002a19-0000-1000-8000-00805f9b34fb"

# Session Control opcodes
OP_START_SESSION  = 0x01
OP_STOP_SESSION   = 0x02
OP_SYNC_TIME      = 0x03
OP_ZERO_CALIBRATE = 0x04
OP_SET_TARGET     = 0x05

# Device states
STATE_BOOT    = 0
STATE_STANDBY = 1
STATE_PREP    = 2
STATE_TRAIN   = 3
STATE_REST    = 4
STATE_SUMMARY = 5

# Timing
NOTIFY_INTERVAL_SEC = 0.050   # 20 Hz notify, 10 samples per packet
SAMPLES_PER_PACKET  = 10

# Orifice level -> simulated peak pressure
ORIFICE_PEAK = {0: 13.0, 1: 22.0, 2: 30.0}

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("ble-sim")


# ---------------------------------------------------------------------------
# Simulated device state
# ---------------------------------------------------------------------------

class Device:
    def __init__(self) -> None:
        self.state = STATE_STANDBY
        self.orifice = 1  # medium
        self.battery_pct = 80
        self.seq = 0
        self.wave = WaveformGenerator(BreathingConfig(peak_cmh2o=ORIFICE_PEAK[1]))
        self.session_start_ts: float | None = None
        self.start_epoch: int = 0
        self.max_pressure = 0.0
        self.samples_sum = 0.0
        self.samples_active = 0  # count of samples >= 5 cmH2O for avg
        self.endurance_sec = 0.0
        self.target_hits = 0
        self._in_zone_since: float | None = None
        self.target_low = 20.0
        self.target_high = 30.0
        self.session_id = 0

    def start_session(self, orifice: int) -> None:
        self.orifice = max(0, min(2, orifice))
        self.wave.set_peak(ORIFICE_PEAK[self.orifice])
        self.state = STATE_TRAIN
        self.session_start_ts = time.monotonic()
        self.max_pressure = 0.0
        self.samples_sum = 0.0
        self.samples_active = 0
        self.endurance_sec = 0.0
        self.target_hits = 0
        self._in_zone_since = None
        self.seq = 0
        self.session_id += 1
        log.info("Session started (orifice=%d, peak=%.1f)", self.orifice, ORIFICE_PEAK[self.orifice])

    def stop_session(self) -> None:
        if self.state == STATE_TRAIN:
            self.state = STATE_SUMMARY
            log.info("Session stopped. max=%.1f avg=%.1f endurance=%.1fs hits=%d",
                     self.max_pressure, self._avg_pressure(), self.endurance_sec, self.target_hits)

    def _avg_pressure(self) -> float:
        return self.samples_sum / self.samples_active if self.samples_active else 0.0

    def tick_samples(self, dt_sec: float) -> list[float]:
        """Advance waveform and update statistics."""
        out = []
        for _ in range(SAMPLES_PER_PACKET):
            p = max(0.0, self.wave.next_sample())
            out.append(p)
            if self.state == STATE_TRAIN:
                if p > self.max_pressure:
                    self.max_pressure = p
                if p >= 5.0:
                    self.samples_sum += p
                    self.samples_active += 1
                self._update_endurance(p, dt_sec / SAMPLES_PER_PACKET)
        return out

    def _update_endurance(self, pressure: float, per_sample_dt: float) -> None:
        now = time.monotonic()
        # Hysteresis: enter zone at low, exit at low - 3
        if pressure >= self.target_low:
            if self._in_zone_since is None:
                self._in_zone_since = now
            self.endurance_sec += per_sample_dt
        else:
            if self._in_zone_since is not None:
                held = now - self._in_zone_since
                if held >= 15.0:
                    self.target_hits += 1
                self._in_zone_since = None

    def build_pressure_packet(self, samples: list[float]) -> bytes:
        """22 B: seq (u16 LE) + 10 × int16 LE (cmH2O × 10)."""
        self.seq = (self.seq + 1) & 0xFFFF
        raw = [max(-32768, min(32767, int(round(s * 10)))) for s in samples]
        return struct.pack("<H" + "h" * SAMPLES_PER_PACKET, self.seq, *raw)

    def build_state_packet(self) -> bytes:
        flags = 0x02  # bleConnected
        if self.battery_pct < 15:
            flags |= 0x04
        return struct.pack("<BBBB", self.state, self.orifice, self.battery_pct, flags)

    def build_summary_packet(self) -> bytes:
        duration = int(time.monotonic() - self.session_start_ts) if self.session_start_ts else 0
        return struct.pack(
            "<IIffIBBHII",
            self.start_epoch,
            duration,
            float(self.max_pressure),
            float(self._avg_pressure()),
            int(self.endurance_sec),
            self.orifice,
            min(255, self.target_hits),
            min(65535, duration * 100),  # sample count approx
            0,  # crc32 placeholder (app validates real device only)
            self.session_id,
        )


device = Device()
server: BlessServer | None = None


# ---------------------------------------------------------------------------
# GATT read/write callbacks
# ---------------------------------------------------------------------------

def read_handler(characteristic: BlessGATTCharacteristic, **_: Any) -> bytearray:
    uuid = characteristic.uuid.lower()
    if uuid == DEVICE_STATE_UUID:
        return bytearray(device.build_state_packet())
    if uuid == SESSION_SUMMARY_UUID:
        return bytearray(device.build_summary_packet())
    if uuid == BATTERY_LEVEL_UUID:
        return bytearray([device.battery_pct])
    if uuid == HISTORY_LIST_UUID:
        # Single stub entry for now
        entry = struct.pack("<IHH", device.session_id or 1, 250, 900)
        return bytearray(bytes([1]) + entry)
    return bytearray()


def write_handler(characteristic: BlessGATTCharacteristic, value: bytearray, **_: Any) -> None:
    if characteristic.uuid.lower() != SESSION_CONTROL_UUID:
        return
    if not value:
        return
    opcode = value[0]
    payload = value[1:]
    log.info("Write opcode=0x%02X payload=%s", opcode, payload.hex())

    if opcode == OP_START_SESSION and len(payload) >= 1:
        device.start_session(payload[0])
    elif opcode == OP_STOP_SESSION:
        device.stop_session()
    elif opcode == OP_SYNC_TIME and len(payload) >= 4:
        device.start_epoch = struct.unpack("<I", payload[:4])[0]
        log.info("Time synced to epoch %d", device.start_epoch)
    elif opcode == OP_ZERO_CALIBRATE:
        log.info("Zero calibration requested (simulated)")
    elif opcode == OP_SET_TARGET and len(payload) >= 2:
        device.target_low = float(payload[0])
        device.target_high = float(payload[1])
        log.info("Target zone set to %.0f~%.0f", device.target_low, device.target_high)


# ---------------------------------------------------------------------------
# Notify loop
# ---------------------------------------------------------------------------

async def notify_loop() -> None:
    assert server is not None
    last_state = -1
    last_summary_pushed = False
    while True:
        t0 = time.monotonic()

        if device.state == STATE_TRAIN:
            samples = device.tick_samples(NOTIFY_INTERVAL_SEC)
            packet = device.build_pressure_packet(samples)
            try:
                await server.write_gatt_char(PRESSURE_STREAM_UUID, bytearray(packet))
            except Exception as e:
                log.debug("Notify send failed: %s", e)
            last_summary_pushed = False
        else:
            # Keep clock advancing so baseline noise is plausible if app is viewing
            device.wave.next_sample()

        # State change notify
        if device.state != last_state:
            last_state = device.state
            try:
                await server.write_gatt_char(DEVICE_STATE_UUID, bytearray(device.build_state_packet()))
            except Exception:
                pass

        # Summary notify once when entering SUMMARY
        if device.state == STATE_SUMMARY and not last_summary_pushed:
            try:
                await server.write_gatt_char(SESSION_SUMMARY_UUID, bytearray(device.build_summary_packet()))
            except Exception:
                pass
            last_summary_pushed = True
            # Auto-return to STANDBY after 3s
            await asyncio.sleep(3.0)
            device.state = STATE_STANDBY

        elapsed = time.monotonic() - t0
        await asyncio.sleep(max(0.0, NOTIFY_INTERVAL_SEC - elapsed))


# ---------------------------------------------------------------------------
# GATT server setup
# ---------------------------------------------------------------------------

async def run() -> None:
    global server

    server = BlessServer(name=DEVICE_NAME)
    server.read_request_func = read_handler
    server.write_request_func = write_handler

    # BlowFit Training Service
    await server.add_new_service(SERVICE_UUID)

    notify_props = GATTCharacteristicProperties.notify | GATTCharacteristicProperties.read
    write_props  = GATTCharacteristicProperties.write
    read_props   = GATTCharacteristicProperties.read

    rw_perm = GATTAttributePermissions.readable | GATTAttributePermissions.writeable

    await server.add_new_characteristic(
        SERVICE_UUID, PRESSURE_STREAM_UUID, notify_props, None, rw_perm
    )
    await server.add_new_characteristic(
        SERVICE_UUID, SESSION_CONTROL_UUID, write_props, None, rw_perm
    )
    await server.add_new_characteristic(
        SERVICE_UUID, SESSION_SUMMARY_UUID, notify_props, None, rw_perm
    )
    await server.add_new_characteristic(
        SERVICE_UUID, DEVICE_STATE_UUID, notify_props, None, rw_perm
    )
    await server.add_new_characteristic(
        SERVICE_UUID, HISTORY_LIST_UUID, read_props, None, rw_perm
    )

    # Battery Service
    await server.add_new_service(BATTERY_SERVICE_UUID)
    await server.add_new_characteristic(
        BATTERY_SERVICE_UUID, BATTERY_LEVEL_UUID, notify_props, bytearray([device.battery_pct]), rw_perm
    )

    await server.start()
    log.info("Advertising as '%s'", DEVICE_NAME)
    log.info("Service UUID: %s", SERVICE_UUID)
    log.info("Waiting for central... Ctrl+C to stop.")

    try:
        await notify_loop()
    finally:
        await server.stop()


def main() -> None:
    try:
        asyncio.run(run())
    except KeyboardInterrupt:
        log.info("Shutting down")
        sys.exit(0)


if __name__ == "__main__":
    main()
