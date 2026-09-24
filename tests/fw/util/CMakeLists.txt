# SPDX-FileCopyrightText: 2026 Core Devices LLC
# SPDX-License-Identifier: Apache-2.0

pbl_clar_test(test_base64
  SOURCES
    src/fw/util/base64.c
)

pbl_clar_test(test_shared_circular_buffer
  SOURCES
    src/fw/util/shared_circular_buffer.c
)

pbl_clar_test(test_time
  SOURCES
    src/fw/util/time/time.c
    src/fw/util/time/mktime.c
    tests/fakes/fake_rtc.c
)

pbl_clar_test(test_dict
  SOURCES
    src/fw/util/dict.c
)

pbl_clar_test(test_buffer
  SOURCES
    src/fw/util/buffer.c
)

pbl_clar_test(test_lru_cache
  SOURCES
    src/fw/util/lru_cache.c
)

pbl_clar_test(test_mbuf
  SOURCES
    src/fw/util/mbuf.c
    src/fw/util/mbuf_iterator.c
)

pbl_clar_test(test_rand
  SOURCES
    src/fw/util/rand/rand.c
    third_party/tinymt/TinyMT/tinymt/tinymt32.c
)

pbl_clar_test(test_stats
  SOURCES
    src/fw/util/stats.c
)

pbl_clar_test(test_legacy_checksum
  SOURCES
    src/fw/util/legacy_checksum.c
)

pbl_clar_test(test_generic_attribute
  SOURCES
    src/fw/util/rand/rand.c
    src/fw/util/generic_attribute.c
    third_party/tinymt/TinyMT/tinymt/tinymt32.c
)

pbl_clar_test(test_hdlc
  SOURCES
    src/fw/util/hdlc.c
)

pbl_clar_test(test_stringlist
  SOURCES
    src/fw/util/stringlist.c
)

pbl_clar_test(test_pstring
  SOURCES
    src/fw/util/pstring.c
)

pbl_clar_test(test_ihex
  SOURCES
    src/fw/util/ihex.c
)

pbl_clar_test(test_sle
  SOURCES
    src/fw/util/sle.c
)

# HPKE (RFC 9180) recipient-side Export, checked against the RFC 9180 A.3 vectors.
# Links the mbed TLS primitives hpke.c uses, built for the host with the firmware's
# mbed TLS config.
pbl_clar_test(test_hpke
  SOURCES
    src/fw/util/hpke.c
    third_party/mbedtls/mbedtls/library/aes.c
    third_party/mbedtls/mbedtls/library/bignum.c
    third_party/mbedtls/mbedtls/library/bignum_core.c
    third_party/mbedtls/mbedtls/library/constant_time.c
    third_party/mbedtls/mbedtls/library/ecp.c
    third_party/mbedtls/mbedtls/library/ecp_curves.c
    third_party/mbedtls/mbedtls/library/gcm.c
    third_party/mbedtls/mbedtls/library/cipher.c
    third_party/mbedtls/mbedtls/library/cipher_wrap.c
    third_party/mbedtls/mbedtls/library/hkdf.c
    third_party/mbedtls/mbedtls/library/md.c
    third_party/mbedtls/mbedtls/library/platform.c
    third_party/mbedtls/mbedtls/library/platform_util.c
    third_party/mbedtls/mbedtls/library/sha256.c
  DEFINES
    CONFIG_MBEDTLS
    MBEDTLS_CONFIG_FILE="pebble_mbedtls_config.h"
  INCLUDES
    third_party/mbedtls/mbedtls/include
    third_party/mbedtls/include
)
