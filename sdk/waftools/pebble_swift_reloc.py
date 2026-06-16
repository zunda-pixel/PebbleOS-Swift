# SPDX-License-Identifier: Apache-2.0
"""Detect app relocations the Pebble loader cannot fix up.

The loader only adds the load base to relocations harvested from .rel.data and
.got. The app linker script merges .data.* into .data and .rodata into .text, so
a valid position-independent app only carries absolute relocations
(R_ARM_ABS32 and friends) in .rel.data. An absolute relocation in any other
loaded section would be left pointing at link address 0 and crash at load.

This is run as a build step for Swift apps (whose codegen could in principle
emit such a relocation) and is also usable standalone. It has no waflib
dependency so it can be unit tested.
"""

import re
import subprocess
import sys

ABSOLUTE_RELOCS = ("R_ARM_ABS32", "R_ARM_ABS16", "R_ARM_ABS8", "R_ARM_TARGET1")
_RELOC_SECTION_RE = re.compile(r"Relocation section '\.rela?(\.[^']*)'")


def _is_ignored_section(name):
    # .data and the merged .data.* are loader-fixed; debug/attributes/comment
    # are not loaded.
    return (name == ".data" or name.startswith(".data.")
            or name.startswith(".debug") or name in (".ARM.attributes", ".comment"))


def scan_unsupported_relocs(readelf_output):
    """Return [(section, reloc_type, symbol)] for absolute relocs outside .data."""
    bad = []
    target = None
    for line in readelf_output.splitlines():
        m = _RELOC_SECTION_RE.search(line)
        if m:
            target = m.group(1)
            continue
        if target is None or _is_ignored_section(target):
            continue
        for reloc in ABSOLUTE_RELOCS:
            if reloc in line:
                parts = line.split()
                bad.append((target, reloc, parts[-1] if parts else "?"))
                break
    return bad


def main(argv):
    """CLI: pebble_swift_reloc.py <readelf> <app.elf>; nonzero on bad relocs."""
    if len(argv) != 3:
        sys.stderr.write("usage: pebble_swift_reloc.py <readelf> <elf>\n")
        return 2
    readelf, elf = argv[1], argv[2]
    out = subprocess.check_output([readelf, "-r", elf]).decode(errors="replace")
    bad = scan_unsupported_relocs(out)
    if bad:
        sys.stderr.write("error: app has absolute relocations the Pebble loader "
                         "cannot fix up (only .rel.data and .got are applied):\n")
        for section, reloc, sym in bad[:20]:
            sys.stderr.write("  {} in {} -> {}\n".format(reloc, section, sym))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
