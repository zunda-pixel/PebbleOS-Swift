// SPDX-License-Identifier: Apache-2.0
//
// An interactive Pebble watch app in Embedded Swift: UP/DOWN change a counter
// shown on screen. @main provides the `main` entry symbol (no C shim).
//
// Button handlers must be C function pointers, which in Embedded Swift means
// non-capturing closures, so the counter and its label are module globals.

private var sCounter: Int32 = 0
private var sLabel: OpaquePointer?

private func refresh() {
  if let label = sLabel {
    text_layer_set_text(label, swift_format_int(sCounter))
  }
}

// Non-capturing closures (they touch only globals), assignable to the imported
// C function-pointer types.
private let onUp: ClickHandler = { _, _ in sCounter += 1; refresh() }
private let onDown: ClickHandler = { _, _ in sCounter -= 1; refresh() }
private let onSelect: ClickHandler = { _, _ in sCounter = 0; refresh() }

private let clickConfig: ClickConfigProvider = { _ in
  window_single_click_subscribe(BUTTON_ID_UP, onUp)
  window_single_click_subscribe(BUTTON_ID_DOWN, onDown)
  window_single_click_subscribe(BUTTON_ID_SELECT, onSelect)
}

//! A text line bound to the counter; captures its layer so the button handlers
//! can update it in place.
struct CounterValue: PebbleView {
  func render(into parent: OpaquePointer?, _ layout: inout Layout) {
    let frame = GRect(origin: GPoint(x: 0, y: layout.y),
                      size: GSize(w: layout.width, h: layout.lineHeight))
    let label = text_layer_create(frame)
    sLabel = label
    text_layer_set_text(label, swift_format_int(sCounter))
    text_layer_set_text_alignment(label, GTextAlignmentCenter)
    layer_add_child(parent, text_layer_get_layer(label))
    layout.y += layout.lineHeight
  }
  func measure(_ layout: inout Layout) { layout.y += layout.lineHeight }
}

@main
struct CounterApp: PebbleApp {
  var body: some PebbleScene {
    Window(clicks: clickConfig) {
      Text("Swift Counter")
      CounterValue()
      Text("Up / Down")
    }
  }
}
