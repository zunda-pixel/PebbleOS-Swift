# SPDX-License-Identifier: Apache-2.0

import os
import sys
import unittest

# pebble_swift_reloc lives in the SDK waftools (bundled into the SDK's waf).
sdk_waftools = os.path.abspath(
    os.path.join(os.path.dirname(__file__), os.pardir, os.pardir, "sdk", "waftools"))
sys.path.insert(0, sdk_waftools)

from pebble_swift_reloc import scan_unsupported_relocs


class TestScanUnsupportedRelocs(unittest.TestCase):
    def test_abs32_in_data_and_debug_is_ok(self):
        out = (
            "Relocation section '.rel.text' at offset 0x1 contains 1 entries:\n"
            " 00000004  R_ARM_THM_CALL  window_create\n"
            "Relocation section '.rel.data' at offset 0x2 contains 1 entries:\n"
            " 0000000c  R_ARM_ABS32  ClassMetadata\n"
            "Relocation section '.rel.debug_info' at offset 0x3 contains 1 entries:\n"
            " 00000008  R_ARM_ABS32  .debug_str\n"
        )
        self.assertEqual(scan_unsupported_relocs(out), [])

    def test_abs32_in_text_is_flagged(self):
        out = (
            "Relocation section '.rel.text' at offset 0x1 contains 1 entries:\n"
            " 00000010  R_ARM_ABS32  someGlobal\n"
        )
        self.assertEqual(scan_unsupported_relocs(out),
                         [(".text", "R_ARM_ABS32", "someGlobal")])

    def test_abs32_in_rodata_is_flagged(self):
        out = (
            "Relocation section '.rela.rodata' at offset 0x1 contains 1 entries:\n"
            " 00000010  R_ARM_ABS32  table\n"
        )
        self.assertEqual(scan_unsupported_relocs(out),
                         [(".rodata", "R_ARM_ABS32", "table")])

    def test_pc_relative_and_got_are_ok(self):
        out = (
            "Relocation section '.rel.text' at offset 0x1 contains 3 entries:\n"
            " 00000000  R_ARM_PREL31  .text\n"
            " 00000004  R_ARM_THM_JUMP24  free\n"
            " 00000008  R_ARM_GOT_PREL  __stack_chk_guard\n"
        )
        self.assertEqual(scan_unsupported_relocs(out), [])

    def test_data_subsection_is_ok(self):
        out = (
            "Relocation section '.rel.data.rel.ro' at offset 0x1 contains 1 entries:\n"
            " 00000000  R_ARM_ABS32  vtable\n"
        )
        self.assertEqual(scan_unsupported_relocs(out), [])


if __name__ == "__main__":
    unittest.main()
