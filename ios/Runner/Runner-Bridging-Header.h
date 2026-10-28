#import "GeneratedPluginRegistrant.h"

#include <stdint.h>

// Clang atomics on Swift's aligned stable allocation. High 32 bits are a
// capture epoch; low bits hold drop count and an active bit. A late callback's
// CAS cannot charge the next run, even when stop/restart races it.
static inline void ShioriProbeCounterBegin(int64_t *counter) {
  int64_t old = __atomic_load_n(counter, __ATOMIC_RELAXED);
  uint64_t epoch = ((uint64_t)old >> 32) + 1;
  __atomic_store_n(counter, (int64_t)((epoch << 32) | 1), __ATOMIC_RELAXED);
}
static inline int64_t ShioriProbeCounterTicket(int64_t *counter) {
  return __atomic_load_n(counter, __ATOMIC_RELAXED);
}
static inline void ShioriProbeCounterDrop(int64_t *counter, int64_t ticket) {
  if (!(ticket & 1)) return;
  uint64_t epoch = (uint64_t)ticket >> 32;
  int64_t value = __atomic_load_n(counter, __ATOMIC_RELAXED);
  while ((value & 1) && ((uint64_t)value >> 32) == epoch) {
    if (__atomic_compare_exchange_n(counter, &value, value + 2, 0,
        __ATOMIC_RELAXED, __ATOMIC_RELAXED)) return;
  }
}
static inline int64_t ShioriProbeCounterEnd(int64_t *counter) {
  int64_t value = __atomic_fetch_and(counter, ~INT64_C(1), __ATOMIC_RELAXED);
  return (value & 1) ? ((uint64_t)value & UINT64_C(0xffffffff)) >> 1 : 0;
}
