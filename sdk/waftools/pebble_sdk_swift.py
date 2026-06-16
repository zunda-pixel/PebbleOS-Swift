# SPDX-License-Identifier: Apache-2.0
#
# Compile Embedded Swift sources for a Pebble app and link them into the C
# program produced by pbl_build.
#
# Swift is built freestanding (Embedded mode, no Swift runtime) for the same
# cortex-m3 / soft-float / position-independent ABI as C apps; its relocations
# land in .got/.rel.data, which the app loader fixes up. The Swift object is
# appended to the app's existing C link, so @main can provide `main` (no C shim
# required) and Swift can call the firmware API imported from pebble.h.

import os
import shutil
import subprocess

from waflib import Task
from waflib.TaskGen import after_method, before_method, feature

from sdk_helpers import find_sdk_component

SWIFT_TARGET = "armv7em-none-none-eabi"
SWIFT_FLAGS = [
    "-enable-experimental-feature", "Embedded",
    "-wmo", "-Osize",
    "-parse-as-library",                       # @main supplies the `main` symbol
    "-Xfrontend", "-function-sections",        # let --gc-sections drop unused runtime
    "-Xfrontend", "-disable-stack-protector",  # avoid __stack_chk_* (unavailable)
]

_SYSROOT_INCLUDE = None


def _sysroot_include():
    """newlib include dir; pebble.h pulls in stdio/locale/string for the importer."""
    global _SYSROOT_INCLUDE
    if _SYSROOT_INCLUDE is None:
        gcc = shutil.which("arm-none-eabi-gcc")
        sysroot = ""
        if gcc:
            try:
                sysroot = subprocess.check_output([gcc, "-print-sysroot"]).decode().strip()
            except Exception:
                sysroot = ""
        _SYSROOT_INCLUDE = os.path.join(sysroot, "include") if sysroot else ""
    return _SYSROOT_INCLUDE


def configure(conf):
    conf.find_program("swiftc", var="SWIFTC", mandatory=True)


class swiftc(Task.Task):
    color = "PINK"

    def run(self):
        swiftc_bin = shutil.which("swiftc")
        if not swiftc_bin:
            self.generator.bld.fatal("swiftc not found on PATH (required for Swift apps)")
        cmd = [swiftc_bin, "-c"] + [s.abspath() for s in self.inputs]
        cmd += ["-o", self.outputs[0].abspath(), "-target", SWIFT_TARGET] + SWIFT_FLAGS
        # Match the Pebble app C ABI for imported declarations: variable-size
        # enums, 32-bit time_t, and suppress newlib's <time.h> so pebble.h's own
        # struct tm is used (this is what the C app build does).
        cmd += ["-Xcc", "-fshort-enums", "-Xcc", "-D_TIME_H_", "-Xcc", "-Dtime_t=long"]
        inc = _sysroot_include()
        if inc:
            cmd += ["-Xcc", "-isystem", "-Xcc", inc]
        for i in self.swift_includes:
            cmd += ["-Xcc", "-I" + i]
        if self.swift_bridging_header:
            cmd += ["-import-objc-header", self.swift_bridging_header]
        return self.exec_command(cmd)


@feature("pebble_cprogram")
@before_method("process_source")
def add_swift_runtime(tg):
    """Add the SDK C runtime shim (posix_memalign + EABI mem helpers) so Swift
    heap types work. Unused functions are dropped by --gc-sections."""
    if not getattr(tg, "swift_source", None):
        return
    runtime = find_sdk_component(tg.bld, tg.env, "swift/pebble_swift_runtime.c")
    if runtime is None:
        return
    src = tg.to_nodes(getattr(tg, "source", []))
    src.append(runtime)
    tg.source = src


@feature("pebble_cprogram")
@after_method("apply_link")
def compile_swift_sources(tg):
    """If the app supplies swift_source, compile it and add it to the link."""
    swift_source = getattr(tg, "swift_source", None)
    if not swift_source:
        return
    nodes = tg.to_nodes(swift_source)

    bld = tg.bld

    # Compile the SDK-shipped PebbleUI framework together with the app's own
    # Swift sources (whole-module). PebbleUI is owned by the SDK -- there is no
    # per-project copy.
    pebble_ui = find_sdk_component(bld, tg.env, "swift/PebbleUI.swift")
    if pebble_ui is not None:
        nodes = [pebble_ui] + nodes
    if not nodes:
        return

    build_node = tg.path.get_bld().make_node(tg.env.BUILD_DIR)  # build/<platform>
    swift_obj = build_node.make_node("swift_app.o")

    task = tg.create_task("swiftc", nodes, [swift_obj])

    # App-provided bridging header, else the SDK default (#include <pebble.h>).
    bridging = getattr(tg, "swift_bridging_header", None)
    bridging_node = (
        bld.path.find_node(bridging) if bridging
        else find_sdk_component(bld, tg.env, "swift/bridging.h")
    )
    task.swift_bridging_header = bridging_node.abspath() if bridging_node else None

    # SDK platform headers + the build dirs holding the generated headers that
    # pebble.h pulls in (message_keys.auto.h, src/resource_ids.auto.h).
    task.swift_includes = [
        find_sdk_component(bld, tg.env, "include").abspath(),
        bld.bldnode.make_node("include").abspath(),
        build_node.abspath(),
    ]

    # Rebuild when the generated headers or the bridging header change, and run
    # after the generated headers exist.
    task.dep_nodes = [
        bld.bldnode.find_or_declare("include/message_keys.auto.h"),
        build_node.find_or_declare("src/resource_ids.auto.h"),
    ]
    if bridging_node is not None:
        task.dep_nodes.append(bridging_node)

    tg.link_task.inputs.append(swift_obj)
    tg.link_task.set_run_after(task)
