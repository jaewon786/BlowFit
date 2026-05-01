// PC-buildable unit test for power module (voltage → battery%).
// Compile: g++ -std=c++17 -I.. test_power.cpp -o test_power && ./test_power

#include <cstdio>
#include <cstdint>

#include "../power.cpp"

using namespace power;

static int g_failures = 0;
#define CHECK(expr) do { \
  if (!(expr)) { \
    std::printf("FAIL %s:%d  %s\n", __FILE__, __LINE__, #expr); \
    g_failures++; \
  } \
} while (0)

#define CHECK_EQ(a, b) do { \
  if ((a) != (b)) { \
    std::printf("FAIL %s:%d  %s = %d, expected %d\n", \
                __FILE__, __LINE__, #a, (int)(a), (int)(b)); \
    g_failures++; \
  } \
} while (0)

static void test_full_charge_voltage_returns_100pct() {
  CHECK_EQ(voltageToPct(4.15f), 100);
  CHECK_EQ(voltageToPct(4.20f), 100);  // above max → clamp
  CHECK_EQ(voltageToPct(5.00f), 100);
}

static void test_empty_voltage_returns_0pct() {
  CHECK_EQ(voltageToPct(3.30f), 0);
  CHECK_EQ(voltageToPct(3.00f), 0);   // below min → clamp
  CHECK_EQ(voltageToPct(0.00f), 0);
}

static void test_midpoint_voltage_returns_50pct() {
  // (3.30 + 4.15) / 2 = 3.725 V → 50%
  const uint8_t pct = voltageToPct(3.725f);
  CHECK(pct >= 49 && pct <= 51); // float rounding tolerance
}

static void test_quarter_voltage_returns_25pct() {
  // 3.30 + 0.85*0.25 = 3.5125 V → 25%
  const uint8_t pct = voltageToPct(3.5125f);
  CHECK(pct >= 24 && pct <= 26);
}

static void test_three_quarter_voltage_returns_75pct() {
  // 3.30 + 0.85*0.75 = 3.9375 V → 75%
  const uint8_t pct = voltageToPct(3.9375f);
  CHECK(pct >= 74 && pct <= 76);
}

static void test_just_above_min_is_low_but_nonzero() {
  // 3.31 V → ~1% (just barely above empty)
  const uint8_t pct = voltageToPct(3.31f);
  CHECK(pct <= 2);
}

static void test_just_below_max_is_high_but_under_100() {
  // 4.14 V → ~98%
  const uint8_t pct = voltageToPct(4.14f);
  CHECK(pct >= 97 && pct <= 99);
}

static void test_voltage_pct_is_monotonic_nondecreasing() {
  uint8_t prev = 0;
  for (int i = 0; i <= 100; i++) {
    const float v = 3.20f + 0.01f * i;  // 3.20 ~ 4.20
    const uint8_t pct = voltageToPct(v);
    CHECK(pct >= prev);
    prev = pct;
  }
}

int main() {
  test_full_charge_voltage_returns_100pct();
  test_empty_voltage_returns_0pct();
  test_midpoint_voltage_returns_50pct();
  test_quarter_voltage_returns_25pct();
  test_three_quarter_voltage_returns_75pct();
  test_just_above_min_is_low_but_nonzero();
  test_just_below_max_is_high_but_under_100();
  test_voltage_pct_is_monotonic_nondecreasing();
  if (g_failures == 0) {
    std::printf("ALL TESTS PASSED\n");
    return 0;
  }
  std::printf("%d FAILURE(S)\n", g_failures);
  return 1;
}
