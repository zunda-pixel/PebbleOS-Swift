// SPDX-License-Identifier: Apache-2.0
//
// PebbleUI: a tiny SwiftUI-like declarative layer over the Pebble C API, in
// Embedded Swift. Shipped by the SDK (build/sdk/common/swift) and compiled
// together with the app's own Swift sources -- there is no per-project copy.
//
// Everything is value types + static generic specialization: Embedded Swift has
// no existentials (`any`), no runtime casts, and cannot call a protocol method
// across a parameter pack, so view composition uses fixed-arity result-builder
// overloads nesting into `Pair`. Layout is a single pass over the `Pair` tree
// using a cursor (`LayoutCtx`) that advances along the current axis.

// MARK: - Layout core

public enum Axis { case vertical, horizontal }

//! A cursor threaded through a container's children as they are placed.
public struct LayoutCtx {
  public var origin: GPoint   // top-left for the next child
  public let cross: Int16     // cross-axis extent available to children
  public let perItem: Int16   // main-axis size per child for fixed division (HStack); 0 -> intrinsic
  public let axis: Axis
  public let spacing: Int16
  public let lineHeight: Int16
}

//! Carve a child's frame out of the cursor and advance it along the axis.
@inline(__always)
func advance(_ ctx: inout LayoutCtx, main m: Int16) -> GRect {
  if ctx.axis == .vertical {
    let frame = GRect(origin: ctx.origin, size: GSize(w: ctx.cross, h: m))
    ctx.origin.y += m + ctx.spacing
    return frame
  } else {
    let frame = GRect(origin: ctx.origin, size: GSize(w: m, h: ctx.cross))
    ctx.origin.x += m + ctx.spacing
    return frame
  }
}

public protocol PebbleView {
  func count() -> Int16                  // number of leaf items (for HStack division)
  func main(_ ctx: LayoutCtx) -> Int16   // main-axis size this view occupies
  func place(_ ctx: inout LayoutCtx, into parent: OpaquePointer?)
}

public protocol PebbleScene {
  func present()
}

// MARK: - Result builder

public struct EmptyView: PebbleView {
  public func count() -> Int16 { 0 }
  public func main(_ ctx: LayoutCtx) -> Int16 { 0 }
  public func place(_ ctx: inout LayoutCtx, into parent: OpaquePointer?) {}
}

public struct Pair<A: PebbleView, B: PebbleView>: PebbleView {
  let a: A
  let b: B
  public func count() -> Int16 { a.count() + b.count() }
  public func main(_ ctx: LayoutCtx) -> Int16 { a.main(ctx) + ctx.spacing + b.main(ctx) }
  public func place(_ ctx: inout LayoutCtx, into parent: OpaquePointer?) {
    a.place(&ctx, into: parent)
    b.place(&ctx, into: parent)
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

// MARK: - Leaf views

public struct Text: PebbleView {
  let text: StaticString
  public init(_ text: StaticString) { self.text = text }
  public func count() -> Int16 { 1 }
  public func main(_ ctx: LayoutCtx) -> Int16 {
    ctx.axis == .vertical ? ctx.lineHeight : (ctx.perItem > 0 ? ctx.perItem : ctx.cross)
  }
  public func place(_ ctx: inout LayoutCtx, into parent: OpaquePointer?) {
    let frame = advance(&ctx, main: main(ctx))
    let label = text_layer_create(frame)
    text_layer_set_text(label, cString(text))
    text_layer_set_text_alignment(label, GTextAlignmentCenter)
    layer_add_child(parent, text_layer_get_layer(label))
  }
}

//! Empty space along the current axis.
public struct Spacer: PebbleView {
  let size: Int16
  public init(_ size: Int16 = 10) { self.size = size }
  public func count() -> Int16 { 1 }
  public func main(_ ctx: LayoutCtx) -> Int16 { size }
  public func place(_ ctx: inout LayoutCtx, into parent: OpaquePointer?) {
    _ = advance(&ctx, main: size)
  }
}

// MARK: - Containers

public struct VStack<Content: PebbleView>: PebbleView {
  let spacing: Int16
  let content: Content
  public init(spacing: Int16 = 0, @SceneBuilder _ content: () -> Content) {
    self.spacing = spacing
    self.content = content()
  }
  public func count() -> Int16 { 1 }
  public func main(_ ctx: LayoutCtx) -> Int16 {
    if ctx.axis == .vertical {
      let inner = LayoutCtx(origin: GPoint(x: 0, y: 0), cross: ctx.cross, perItem: 0,
                            axis: .vertical, spacing: spacing, lineHeight: ctx.lineHeight)
      return content.main(inner)
    }
    return ctx.perItem > 0 ? ctx.perItem : ctx.cross
  }
  public func place(_ ctx: inout LayoutCtx, into parent: OpaquePointer?) {
    let frame = advance(&ctx, main: main(ctx))
    var inner = LayoutCtx(origin: frame.origin, cross: frame.size.w, perItem: 0,
                          axis: .vertical, spacing: spacing, lineHeight: ctx.lineHeight)
    content.place(&inner, into: parent)
  }
}

public struct HStack<Content: PebbleView>: PebbleView {
  let spacing: Int16
  let content: Content
  public init(spacing: Int16 = 0, @SceneBuilder _ content: () -> Content) {
    self.spacing = spacing
    self.content = content()
  }
  public func count() -> Int16 { 1 }
  public func main(_ ctx: LayoutCtx) -> Int16 {
    ctx.axis == .vertical ? ctx.lineHeight : (ctx.perItem > 0 ? ctx.perItem : ctx.cross)
  }
  public func place(_ ctx: inout LayoutCtx, into parent: OpaquePointer?) {
    let frame = advance(&ctx, main: main(ctx))
    let n = max(1, content.count())
    let itemW = (frame.size.w - spacing * (n - 1)) / n
    var inner = LayoutCtx(origin: frame.origin, cross: frame.size.h, perItem: itemW,
                          axis: .horizontal, spacing: spacing, lineHeight: ctx.lineHeight)
    content.place(&inner, into: parent)
  }
}

//! Uniform inset around its content (laid out vertically inside).
public struct Padding<Content: PebbleView>: PebbleView {
  let inset: Int16
  let content: Content
  public init(_ inset: Int16 = 6, @SceneBuilder _ content: () -> Content) {
    self.inset = inset
    self.content = content()
  }
  public func count() -> Int16 { 1 }
  public func main(_ ctx: LayoutCtx) -> Int16 { content.main(ctx) + 2 * inset }
  public func place(_ ctx: inout LayoutCtx, into parent: OpaquePointer?) {
    let frame = advance(&ctx, main: main(ctx))
    var inner = LayoutCtx(origin: GPoint(x: frame.origin.x + inset, y: frame.origin.y + inset),
                          cross: frame.size.w - 2 * inset, perItem: 0,
                          axis: .vertical, spacing: 0, lineHeight: ctx.lineHeight)
    content.place(&inner, into: parent)
  }
}

// MARK: - Window / app entry

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
    let lineHeight: Int16 = 28

    let probe = LayoutCtx(origin: GPoint(x: 0, y: 0), cross: bounds.size.w, perItem: 0,
                          axis: .vertical, spacing: 0, lineHeight: lineHeight)
    let totalH = content.main(probe)
    let startY = totalH < bounds.size.h ? (bounds.size.h - totalH) / 2 : 0

    var ctx = LayoutCtx(origin: GPoint(x: 0, y: startY), cross: bounds.size.w, perItem: 0,
                        axis: .vertical, spacing: 0, lineHeight: lineHeight)
    content.place(&ctx, into: root)

    if let clickProvider {
      window_set_click_config_provider(window, clickProvider)
    }
    window_stack_push(window, true)
    app_event_loop()
    window_destroy(window)
  }
}

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
public func cString(_ s: StaticString) -> UnsafePointer<CChar> {
  UnsafeRawPointer(s.utf8Start).assumingMemoryBound(to: CChar.self)
}
