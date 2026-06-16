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
    let label = text_layer_create(frame)!
    text_layer_set_text(label, cString(text))
    text_layer_set_text_alignment(label, GTextAlignmentCenter)
    layer_add_child(parent, text_layer_get_layer(label))
    buildingWindow?.textLayers.append(label)
  }
}

//! A bitmap from an app resource (RESOURCE_ID_*), centered in its slot.
public struct Image: PebbleView {
  let resourceId: UInt32
  let height: Int16
  public init(_ resourceId: UInt32, height: Int16 = 60) {
    self.resourceId = resourceId
    self.height = height
  }
  public func count() -> Int16 { 1 }
  public func main(_ ctx: LayoutCtx) -> Int16 {
    ctx.axis == .vertical ? height : (ctx.perItem > 0 ? ctx.perItem : ctx.cross)
  }
  public func place(_ ctx: inout LayoutCtx, into parent: OpaquePointer?) {
    let frame = advance(&ctx, main: main(ctx))
    let bitmap = gbitmap_create_with_resource(resourceId)!
    let layer = bitmap_layer_create(frame)!
    bitmap_layer_set_bitmap(layer, bitmap)
    bitmap_layer_set_alignment(layer, GAlignCenter)
    layer_add_child(parent, bitmap_layer_get_layer(layer))
    buildingWindow?.bitmapLayers.append(layer)
    buildingWindow?.bitmaps.append(bitmap)
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
  //! Create the window, lay out the content (centered vertically) and push it
  //! onto the window stack. Shared by present() and push().
  @discardableResult
  func realize() -> OpaquePointer? {
    let window = window_create()!
    let root = window_get_root_layer(window)
    let bounds = layer_get_bounds(root)
    let lineHeight: Int16 = 28

    // Collect the layers/bitmaps/labels created during layout so they can be
    // destroyed when this window unloads (popped or app exit).
    let resources = WindowResources(window: window)
    windowResources.append(resources)
    buildingWindow = resources
    defer { buildingWindow = nil }
    window_set_window_handlers(window, WindowHandlers(load: nil, appear: nil,
                                                      disappear: nil, unload: pebbleUIUnload))

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
    return window
  }

  //! Root entry: push and run the app event loop until the app exits.
  public func present() {
    let window = realize()
    app_event_loop()
    window_destroy(window)
  }

  //! Navigate to this window from within a running app (e.g. a click handler).
  //! The back button pops it, returning to the previous window.
  public func push() {
    realize()
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

// MARK: - Reactive state
//
// Heap-backed (needs the SDK runtime shim). Apps that don't use State/Label
// stay heap-free: this code is dropped by --gc-sections when unreferenced.

//! Observable value. Mutating it refreshes every Label currently on screen.
public final class State<Value> {
  public var value: Value {
    didSet { refreshLabels() }
  }
  public init(_ value: Value) { self.value = value }
}

//! A Label keeps its own text_layer + a heap buffer and updates in place when
//! state changes (no full re-render), so static Text views are untouched.
final class LabelBox {
  let layer: OpaquePointer
  let provider: () -> String
  let buf: UnsafeMutablePointer<CChar>
  let cap: Int
  init(layer: OpaquePointer, provider: @escaping () -> String, cap: Int = 64) {
    self.layer = layer
    self.provider = provider
    self.cap = cap
    self.buf = UnsafeMutablePointer<CChar>.allocate(capacity: cap)
    update()
  }
  deinit { buf.deallocate() }
  func update() {
    var i = 0
    for byte in provider().utf8 where i < cap - 1 {
      buf[i] = CChar(bitPattern: byte)
      i += 1
    }
    buf[i] = 0
    text_layer_set_text(layer, UnsafePointer(buf))
  }
}

var liveLabels: [LabelBox] = []

func refreshLabels() {
  for box in liveLabels { box.update() }
}

//! A text view bound to dynamic state; re-evaluated whenever a State changes.
public struct Label: PebbleView {
  let provider: () -> String
  public init(_ provider: @escaping () -> String) { self.provider = provider }
  public func count() -> Int16 { 1 }
  public func main(_ ctx: LayoutCtx) -> Int16 {
    ctx.axis == .vertical ? ctx.lineHeight : (ctx.perItem > 0 ? ctx.perItem : ctx.cross)
  }
  public func place(_ ctx: inout LayoutCtx, into parent: OpaquePointer?) {
    let frame = advance(&ctx, main: main(ctx))
    let layer = text_layer_create(frame)!
    text_layer_set_text_alignment(layer, GTextAlignmentCenter)
    let box = LabelBox(layer: layer, provider: provider)
    liveLabels.append(box)
    buildingWindow?.labels.append(box)
    buildingWindow?.textLayers.append(layer)
    layer_add_child(parent, text_layer_get_layer(layer))
  }
}

// MARK: - Window resource lifecycle
//
// Layers/bitmaps a window creates are destroyed when that window unloads
// (popped, or app exit), and its Labels are removed from the live set so a
// later State change can't update a freed layer. Heap-backed (needs the SDK
// runtime shim).

final class WindowResources {
  let window: OpaquePointer
  var textLayers: [OpaquePointer] = []
  var bitmapLayers: [OpaquePointer] = []
  var bitmaps: [OpaquePointer] = []
  var labels: [LabelBox] = []
  init(window: OpaquePointer) { self.window = window }
}

// The window currently being laid out; leaf views register what they create.
var buildingWindow: WindowResources?
// Live resources per window, freed on unload. A plain array (linear lookup) --
// not a Dictionary, whose hashing would pull in entropy syscalls the app SDK
// lacks. There are only a handful of windows on the stack.
var windowResources: [WindowResources] = []

func destroyWindowResources(_ window: OpaquePointer) {
  guard let i = windowResources.firstIndex(where: { $0.window == window }) else { return }
  let res = windowResources.remove(at: i)
  for box in res.labels {
    if let j = liveLabels.firstIndex(where: { $0 === box }) { liveLabels.remove(at: j) }
  }
  for layer in res.textLayers { text_layer_destroy(layer) }
  for layer in res.bitmapLayers { bitmap_layer_destroy(layer) }
  for bitmap in res.bitmaps { gbitmap_destroy(bitmap) }
}

let pebbleUIUnload: WindowHandler = { window in
  if let window { destroyWindowResources(window) }
}

// MARK: - Helpers

@inline(__always)
public func cString(_ s: StaticString) -> UnsafePointer<CChar> {
  UnsafeRawPointer(s.utf8Start).assumingMemoryBound(to: CChar.self)
}
