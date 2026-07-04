// SPDX-License-Identifier: Apache-2.0
//
// Exposes the Pebble C API to Embedded Swift via the Clang importer.
#include <pebble.h>

// App-local C helpers callable from Swift.
const char *swift_format_int(int32_t value);
