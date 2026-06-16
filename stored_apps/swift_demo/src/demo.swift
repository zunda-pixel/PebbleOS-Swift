// SPDX-License-Identifier: Apache-2.0
//
// Phase 2: the whole app UI is built in Embedded Swift, calling firmware APIs
// (window/text-layer/event-loop) imported from pebble.h via the bridging header.

// Static, null-terminated storage; text_layer_set_text stores the pointer, so
// it must outlive the call (a StaticString literal lives in the app's rodata).
private let kGreeting: StaticString = "Hello from Swift"

private func cString(_ s: StaticString) -> UnsafePointer<CChar> {
  return UnsafeRawPointer(s.utf8Start).assumingMemoryBound(to: CChar.self)
}

@_cdecl("pebble_main")
public func pebbleMain() {
  let window = window_create()
  let root = window_get_root_layer(window)
  let bounds = layer_get_bounds(root)

  let frame = GRect(origin: GPoint(x: 0, y: bounds.size.h / 2 - 30),
                    size: GSize(w: bounds.size.w, h: 60))
  let text = text_layer_create(frame)
  text_layer_set_text(text, cString(kGreeting))
  text_layer_set_text_alignment(text, GTextAlignmentCenter)
  layer_add_child(root, text_layer_get_layer(text))

  window_stack_push(window, true)
  app_event_loop()

  text_layer_destroy(text)
  window_destroy(window)
}
