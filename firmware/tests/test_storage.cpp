// PC-buildable unit test for storage ring buffer.
// Compile: g++ -std=c++17 -I.. test_storage.cpp -o test_storage && ./test_storage
//
// On host (no ARDUINO macro), file I/O in storage.cpp is compiled out, so
// the tests exercise pure in-memory ring buffer logic.

#include <cassert>
#include <cstdio>
#include <cstdint>

#include "../storage.cpp"

using namespace storage;

static int g_failures = 0;
#define CHECK(expr) do { \
  if (!(expr)) { \
    std::printf("FAIL %s:%d  %s\n", __FILE__, __LINE__, #expr); \
    g_failures++; \
  } \
} while (0)

static state_machine::Metrics makeMetrics(uint32_t id, float maxP, uint32_t durMs) {
  state_machine::Metrics m;
  m.sessionId = id;
  m.maxPressure = maxP;
  m.sessionDurationMs = durMs;
  return m;
}

static void test_empty_history() {
  storage::begin();
  HistoryEntry buf[MAX_HISTORY];
  uint8_t n = readHistory(buf);
  CHECK(n == 0);
}

static void test_single_save_and_read() {
  saveSession(makeMetrics(101, 27.5f, 240000));
  HistoryEntry buf[MAX_HISTORY];
  uint8_t n = readHistory(buf);
  CHECK(n == 1);
  CHECK(buf[0].sessionId == 101);
  CHECK(buf[0].maxPressureX10 == 275);
  CHECK(buf[0].durationSec == 240);
}

static void test_newest_first_order() {
  for (uint32_t i = 102; i <= 105; i++) {
    saveSession(makeMetrics(i, 10.0f, 1000));
  }
  HistoryEntry buf[MAX_HISTORY];
  uint8_t n = readHistory(buf);
  CHECK(n == 5);
  CHECK(buf[0].sessionId == 105);
  CHECK(buf[1].sessionId == 104);
  CHECK(buf[2].sessionId == 103);
  CHECK(buf[3].sessionId == 102);
  CHECK(buf[4].sessionId == 101);
}

static void test_fills_to_max() {
  // Already 5 entries; add 25 more to reach exactly MAX_HISTORY = 30.
  for (uint32_t i = 200; i < 225; i++) {
    saveSession(makeMetrics(i, 12.0f, 60000));
  }
  HistoryEntry buf[MAX_HISTORY];
  uint8_t n = readHistory(buf);
  CHECK(n == MAX_HISTORY);
  CHECK(buf[0].sessionId == 224);          // newest
  CHECK(buf[MAX_HISTORY - 1].sessionId == 101); // oldest still id=101
}

static void test_ring_evicts_oldest() {
  // Add one more — should evict id=101 (the oldest).
  saveSession(makeMetrics(999, 15.0f, 5000));
  HistoryEntry buf[MAX_HISTORY];
  uint8_t n = readHistory(buf);
  CHECK(n == MAX_HISTORY);
  CHECK(buf[0].sessionId == 999);
  // Walk all entries and confirm 101 is gone.
  bool found101 = false;
  for (uint8_t i = 0; i < n; i++) if (buf[i].sessionId == 101) found101 = true;
  CHECK(!found101);
}

static void test_ring_wraps_many_times() {
  // Push 100 more entries; only the last 30 should remain.
  for (uint32_t i = 1000; i < 1100; i++) {
    saveSession(makeMetrics(i, 20.0f, 10000));
  }
  HistoryEntry buf[MAX_HISTORY];
  uint8_t n = readHistory(buf);
  CHECK(n == MAX_HISTORY);
  CHECK(buf[0].sessionId == 1099);
  CHECK(buf[MAX_HISTORY - 1].sessionId == 1099 - (MAX_HISTORY - 1));
}

static void test_max_pressure_clamps_to_uint16() {
  saveSession(makeMetrics(2000, 10000.0f, 1000));  // 10000 * 10 = 100000, > 65535
  HistoryEntry buf[MAX_HISTORY];
  readHistory(buf);
  CHECK(buf[0].sessionId == 2000);
  CHECK(buf[0].maxPressureX10 == 65535);
}

static void test_negative_pressure_clamps_to_zero() {
  saveSession(makeMetrics(2001, -5.0f, 1000));
  HistoryEntry buf[MAX_HISTORY];
  readHistory(buf);
  CHECK(buf[0].sessionId == 2001);
  CHECK(buf[0].maxPressureX10 == 0);
}

static void test_duration_clamps_to_uint16() {
  // 70000 sec * 1000 = 70_000_000 ms; sec = 70000 > 65535
  saveSession(makeMetrics(2002, 5.0f, 70000UL * 1000UL));
  HistoryEntry buf[MAX_HISTORY];
  readHistory(buf);
  CHECK(buf[0].sessionId == 2002);
  CHECK(buf[0].durationSec == 65535);
}

int main() {
  test_empty_history();
  test_single_save_and_read();
  test_newest_first_order();
  test_fills_to_max();
  test_ring_evicts_oldest();
  test_ring_wraps_many_times();
  test_max_pressure_clamps_to_uint16();
  test_negative_pressure_clamps_to_zero();
  test_duration_clamps_to_uint16();
  if (g_failures == 0) {
    std::printf("ALL TESTS PASSED\n");
    return 0;
  }
  std::printf("%d FAILURE(S)\n", g_failures);
  return 1;
}
