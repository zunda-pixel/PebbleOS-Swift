// SPDX-License-Identifier: Apache-2.0
//
// Phase 2 Swift demo: the entry point is a thin C shim; all app logic and UI
// live in Embedded Swift (see demo.swift).

extern void pebble_main(void);

int main(void) {
  pebble_main();
  return 0;
}
