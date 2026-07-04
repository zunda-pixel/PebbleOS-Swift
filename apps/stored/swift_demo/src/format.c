// SPDX-License-Identifier: Apache-2.0
//
// Heap-free int -> decimal string for Swift (the app SDK has no snprintf, and
// Swift's String would pull in the allocator). Returns a pointer to a static
// buffer; text_layer_set_text stores the pointer, and the buffer is static, so
// it stays valid and is reused on each update.

#include <stdint.h>

const char *swift_format_int(int32_t value) {
  static char buf[16];
  char tmp[16];
  int i = 0;
  int neg = value < 0;
  uint32_t u = neg ? (uint32_t)(-(int64_t)value) : (uint32_t)value;

  if (u == 0) {
    tmp[i++] = '0';
  }
  while (u != 0) {
    tmp[i++] = (char)('0' + (u % 10));
    u /= 10;
  }

  int j = 0;
  if (neg) {
    buf[j++] = '-';
  }
  while (i > 0) {
    buf[j++] = tmp[--i];
  }
  buf[j] = '\0';
  return buf;
}
