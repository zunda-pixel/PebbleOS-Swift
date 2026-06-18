// SPDX-License-Identifier: Apache-2.0
//
// Minimal C runtime support for Embedded Swift apps. The Pebble app SDK exports
// malloc/free/memcpy/memset/memmove (jump-table trampolines) but not
// posix_memalign (used by Swift's allocator) or the EABI mem helpers (libgcc is
// discarded by the app linker script). Providing these lets Swift use heap
// types (classes, Array, String). Unused functions are dropped by --gc-sections.

#include <stddef.h>

extern void *malloc(size_t size);
extern void *memcpy(void *dest, const void *src, size_t n);
extern void *memmove(void *dest, const void *src, size_t n);
extern void *memset(void *dest, int c, size_t n);

// Swift's swift_slowAlloc calls posix_memalign. The app heap's malloc is at
// least 8-byte aligned (proven by the heap working at all -- class/Array
// headers need it), which covers Embedded Swift's allocations on 32-bit ARM.
// Larger alignments can't be guaranteed: free() must receive malloc's own
// pointer, which rules out an offset/header trick. We therefore return the
// malloc block best-effort rather than failing -- returning an error here would
// abort the Swift allocation and crash the app, and in practice the runtime
// does request >8-byte alignment for some heap storage.
int posix_memalign(void **memptr, size_t alignment, size_t size) {
  (void)alignment;
  void *p = malloc(size);
  *memptr = p;
  return p ? 0 : 12;  // ENOMEM
}

// ARM EABI memory helpers (note __aeabi_memset's (dest, n, c) argument order).
void *__aeabi_memcpy(void *dest, const void *src, size_t n) { return memcpy(dest, src, n); }
void *__aeabi_memcpy4(void *dest, const void *src, size_t n) { return memcpy(dest, src, n); }
void *__aeabi_memcpy8(void *dest, const void *src, size_t n) { return memcpy(dest, src, n); }
void *__aeabi_memmove(void *dest, const void *src, size_t n) { return memmove(dest, src, n); }
void *__aeabi_memmove4(void *dest, const void *src, size_t n) { return memmove(dest, src, n); }
void *__aeabi_memmove8(void *dest, const void *src, size_t n) { return memmove(dest, src, n); }
void *__aeabi_memset(void *dest, size_t n, int c) { return memset(dest, c, n); }
void *__aeabi_memset4(void *dest, size_t n, int c) { return memset(dest, c, n); }
void *__aeabi_memset8(void *dest, size_t n, int c) { return memset(dest, c, n); }
void *__aeabi_memclr(void *dest, size_t n) { return memset(dest, 0, n); }
void *__aeabi_memclr4(void *dest, size_t n) { return memset(dest, 0, n); }
void *__aeabi_memclr8(void *dest, size_t n) { return memset(dest, 0, n); }
