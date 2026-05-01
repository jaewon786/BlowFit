#include "storage.h"

#if defined(ARDUINO) && HAS_FLASH
  #include <Adafruit_LittleFS.h>
  #include <InternalFileSystem.h>
  using namespace Adafruit_LittleFS_Namespace;
  static File openFs(const char* path, uint8_t mode) {
    return InternalFS.open(path, mode);
  }
#endif

#include <string.h>

namespace storage {

namespace {

constexpr const char* HISTORY_PATH = "/history.bin";
constexpr const char* CONFIG_PATH  = "/config.bin";
constexpr uint32_t MAGIC = 0xBA110050;

struct HistoryFile {
  uint32_t magic;
  uint8_t  count;           // 0..MAX_HISTORY
  uint8_t  head;            // index of next write slot (ring)
  uint16_t reserved;
  HistoryEntry entries[MAX_HISTORY];
};

struct ConfigFile {
  uint32_t magic;
  float zeroOffset;
  float targetLow;
  float targetHigh;
  uint32_t crc32;           // Reserved; not validated yet.
};

HistoryFile g_hist;
bool g_loaded = false;

void ensureLoaded() {
  if (g_loaded) return;
#if defined(ARDUINO) && HAS_FLASH
  File f = openFs(HISTORY_PATH, FILE_O_READ);
  if (f && f.size() == sizeof(HistoryFile)) {
    f.read(&g_hist, sizeof(g_hist));
    f.close();
    if (g_hist.magic == MAGIC && g_hist.count <= MAX_HISTORY) {
      g_loaded = true;
      return;
    }
  }
  if (f) f.close();
#endif
  memset(&g_hist, 0, sizeof(g_hist));
  g_hist.magic = MAGIC;
  g_loaded = true;
}

void persist() {
#if defined(ARDUINO) && HAS_FLASH
  File f = openFs(HISTORY_PATH, FILE_O_WRITE);
  if (!f) return;
  f.write((const uint8_t*)&g_hist, sizeof(g_hist));
  f.close();
#endif
}

}  // namespace

void begin() {
#if defined(ARDUINO) && HAS_FLASH
  InternalFS.begin();
#endif
  ensureLoaded();
}

void saveSession(const state_machine::Metrics& m) {
  ensureLoaded();
  HistoryEntry e;
  e.sessionId = m.sessionId;
  float mx = m.maxPressure * 10.0f;
  if (mx < 0) mx = 0;
  if (mx > 65535) mx = 65535;
  e.maxPressureX10 = (uint16_t)mx;
  uint32_t sec = m.sessionDurationMs / 1000;
  e.durationSec = sec > 65535 ? 65535 : (uint16_t)sec;

  g_hist.entries[g_hist.head] = e;
  g_hist.head = (g_hist.head + 1) % MAX_HISTORY;
  if (g_hist.count < MAX_HISTORY) g_hist.count++;
  persist();
}

uint8_t readHistory(HistoryEntry out[MAX_HISTORY]) {
  ensureLoaded();
  // Newest-first: start at (head - 1) and walk backwards count times.
  uint8_t n = g_hist.count;
  for (uint8_t i = 0; i < n; i++) {
    uint8_t idx = (g_hist.head + MAX_HISTORY - 1 - i) % MAX_HISTORY;
    out[i] = g_hist.entries[idx];
  }
  return n;
}

void saveConfig(float zeroOffset, float targetLow, float targetHigh) {
#if defined(ARDUINO) && HAS_FLASH
  ConfigFile c{ MAGIC, zeroOffset, targetLow, targetHigh, 0 };
  File f = openFs(CONFIG_PATH, FILE_O_WRITE);
  if (!f) return;
  f.write((const uint8_t*)&c, sizeof(c));
  f.close();
#else
  (void)zeroOffset; (void)targetLow; (void)targetHigh;
#endif
}

bool loadConfig(float& zeroOffset, float& targetLow, float& targetHigh) {
#if defined(ARDUINO) && HAS_FLASH
  File f = openFs(CONFIG_PATH, FILE_O_READ);
  if (!f || f.size() != sizeof(ConfigFile)) { if (f) f.close(); return false; }
  ConfigFile c;
  f.read(&c, sizeof(c));
  f.close();
  if (c.magic != MAGIC) return false;
  zeroOffset = c.zeroOffset;
  targetLow  = c.targetLow;
  targetHigh = c.targetHigh;
  return true;
#else
  (void)zeroOffset; (void)targetLow; (void)targetHigh;
  return false;
#endif
}

}  // namespace storage
