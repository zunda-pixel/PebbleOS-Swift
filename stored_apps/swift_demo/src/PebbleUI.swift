// SPDX-License-Identifier: Apache-2.0
//
// A tiny SwiftUI-like declarative layer over the Pebble C API, written in
// Embedded Swift. Everything is value types + static generic specialization:
// Embedded Swift has no existentials (`any`), no runtime casts, and cannot call
// a protocol method across a parameter pack, so view composition uses
// fixed-arity result-builder overloads that nest into `Pair`, and measurement
// is a plain protocol requirement (statically dispatched) rather than a cast.

// MARK: - Core protocols

//! Vertical stacking cursor handed down while views render.
public struct Layout {
  public var y: Int16
  public let width: Int16
  public let lineHeight: Int16
}

//! A leaf or container that lays itself out vertically into a layer.
public protocol PebbleView {
  func render(into parent: OpaquePointer?, _ layout: inout Layout)
  //! Advance the cursor exactly as render would, without creating layers, so a
  //! container can measure its content block (e.g. to center it).
  func measure(_ layout: inout Layout)
}

//! A top-level scene that owns a window and runs the app event loop.
public protocol PebbleScene {
  func present()
}

// MARK: - Result builder

public struct EmptyView: PebbleView {
  public func render(into parent: OpaquePointer?, _ layout: inout Layout) {}
  public func measure(_ layout: inout Layout) {}
}

//! Two stacked views; nesting Pairs gives arbitrary arity without packs.
public struct Pair<A: PebbleView, B: PebbleView>: PebbleView {
  let a: A
  let b: B
  public func render(into parent: OpaquePointer?, _ layout: inout Layout) {
    a.render(into: parent, &layout)
    b.render(into: parent, &layout)
  }
  public func measure(_ layout: inout Layout) {
    a.measure(&layout)
    b.measure(&layout)
  }
}

@resultBuilder
public enum SceneBuilder {
  public static func buildBlock() -> EmptyView { EmptyView() }
  public static func buildBlock<A: PebbleView>(_ a: A) -> A { a }
  public static func buildBlock<A: PebbleView, B: PebbleView>(
    _ a: A, _ b: B) -> Pair<A, B> { Pair(a: a, b: b) }
  public static func buildBlock<A: PebbleView, B: PebbleView, C: PebbleView>(
    _ a: A, _ b: B, _ c: C) -> Pair<A, Pair<B, C>> {
    Pair(a: a, b: Pair(a: b, b: c))
  }
  public static func buildBlock<A: PebbleView, B: PebbleView, C: PebbleView, D: PebbleView>(
    _ a: A, _ b: B, _ c: C, _ d: D) -> Pair<A, Pair<B, Pair<C, D>>> {
    Pair(a: a, b: Pair(a: b, b: Pair(a: c, b: d)))
  }
}

// MARK: - Views

//! A line of text. The literal lives in rodata so its pointer outlives the
//! text_layer_set_text call (which stores, not copies, it).
public struct Text: PebbleView {
  let text: StaticString
  public init(_ text: StaticString) { self.text = text }
  public func render(into parent: OpaquePointer?, _ layout: inout Layout) {
    let frame = GRect(origin: GPoint(x: 0, y: layout.y),
                      size: GSize(w: layout.width, h: layout.lineHeight))
    let label = text_layer_create(frame)
    text_layer_set_text(label, cString(text))
    text_layer_set_text_alignment(label, GTextAlignmentCenter)
    layer_add_child(parent, text_layer_get_layer(label))
    layout.y += layout.lineHeight
  }
  public func measure(_ layout: inout Layout) {
    layout.y += layout.lineHeight
  }
}

//! The root scene: creates a window, lays its content out vertically (centered
//! as a block), pushes it, and runs the event loop. An optional click config
//! provider wires up button input (must be a non-capturing @convention(c)
//! function, so handlers communicate through globals).
public struct Window<Content: PebbleView>: PebbleScene {
  let content: Content
  let clickProvider: ClickConfigProvider?
  public init(clicks clickProvider: ClickConfigProvider? = nil,
              @SceneBuilder _ content: () -> Content) {
    self.clickProvider = clickProvider
    self.content = content()
  }
  public func present() {
    let window = window_create()
    let root = window_get_root_layer(window)
    let bounds = layer_get_bounds(root)
    let lineHeight: Int16 = 30

    var probe = Layout(y: 0, width: bounds.size.w, lineHeight: lineHeight)
    content.measure(&probe)
    let startY = probe.y < bounds.size.h ? (bounds.size.h - probe.y) / 2 : 0

    var layout = Layout(y: startY, width: bounds.size.w, lineHeight: lineHeight)
    content.render(into: root, &layout)

    if let clickProvider {
      window_set_click_config_provider(window, clickProvider)
    }
    window_stack_push(window, true)
    app_event_loop()
    window_destroy(window)
  }
}

// MARK: - App entry

public protocol PebbleApp {
  associatedtype Body: PebbleScene
  init()
  var body: Body { get }
}

public extension PebbleApp {
  static func main() {
    Self().body.present()
  }
}

// MARK: - Helpers

@inline(__always)
func cString(_ s: StaticString) -> UnsafePointer<CChar> {
  UnsafeRawPointer(s.utf8Start).assumingMemoryBound(to: CChar.self)
}
